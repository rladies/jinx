#' Airtable base holding directory submissions.
#'
#' The `submissions` table carries one row per directory form submission,
#' with linked `languages`, `countries`, and `interests` tables resolved
#' into human-readable labels during the sync.
#' @keywords internal
directory_base_id <- function() "appzYxePUruG9Nwyg"

#' Checkbox field on the `submissions` table flagging a processed submission.
#'
#' Set to `TRUE` by [directory_mark_synced()] once a submission's entry is live
#' in the directory, so subsequent syncs skip it. Must exist on the table.
#' @keywords internal
directory_synced_field <- function() "synced"

#' Sync directory entries from Airtable
#'
#' Fetches directory submissions from Airtable, transforms each eligible
#' record into the directory entry schema, and opens (or updates) a PR on
#' the directory repo containing only the entries whose content changed.
#'
#' Only submissions marked `minority_gender == "yes"` and not flagged as a
#' `DEFAULT ROW` are processed. Returning submitters are matched to their
#' existing entry by slug (`directory_id`, falling back to `identifier`), and
#' their submission is merged onto the existing file: fields listed in
#' `clear_fields` are wiped first, then submitted fields overlay the rest, so
#' a partial update never drops data the submitter left blank.
#'
#' Delete requests are collected and reported in the PR body but are **not**
#' executed here; destructive removal stays with the reviewed purge workflow.
#'
#' @param base_id Airtable base ID. Defaults to the directory base.
#' @param api_key Airtable API key. Defaults to `AIRTABLE_API_KEY` env var.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param directory_repo Directory repository name.
#' @return PR URL if changes found, `NULL` otherwise (invisibly).
#' @export
directory_sync_airtable <- function(
  base_id = directory_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  directory_repo = "directory"
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }

  cli::cli_h2("Syncing directory from Airtable")
  submissions <- airtable_list_records(base_id, "submissions", api_key)
  submissions <- directory_drop_synced(submissions)
  cli::cli_alert_info("Fetched {length(submissions)} unsynced submission{?s}")

  lookups <- directory_build_lookups(base_id, api_key)

  transformed <- lapply(
    submissions,
    directory_transform_record,
    lookups = lookups
  )
  transformed <- Filter(Negate(is.null), transformed)

  deletes <- Filter(function(e) isTRUE(e$delete), transformed)
  updates <- Filter(function(e) !isTRUE(e$delete), transformed)
  updates <- directory_dedupe_slugs(updates)
  cli::cli_alert_info(
    "{length(updates)} entr{?y/ies} to sync, {length(deletes)} delete{?s}"
  )

  changed <- directory_write_entries(updates, org, directory_repo)

  if (length(changed) == 0 && length(deletes) == 0) {
    cli::cli_alert_success("No changes detected")
    return(invisible(NULL))
  }

  pr_url <- directory_create_pr(changed, deletes, org, directory_repo)
  if (is.null(pr_url)) {
    cli::cli_alert_success("No PR opened; nothing to push")
    return(invisible(NULL))
  }
  cli::cli_alert_success(
    "PR ready with {length(changed)} change{?s}: {pr_url}"
  )
  invisible(pr_url)
}

#' Drop submissions already flagged as synced.
#'
#' A submission carries the [directory_synced_field()] checkbox once its entry
#' is live in the directory; Airtable omits unchecked boxes, so absence means
#' unsynced.
#' @keywords internal
directory_drop_synced <- function(submissions) {
  Filter(
    function(r) !isTRUE(r$fields[[directory_synced_field()]]),
    submissions
  )
}

#' Flag handled submissions as synced.
#'
#' Reconciles Airtable against the directory and flips the
#' [directory_synced_field()] checkbox on every submission whose work is done,
#' so future syncs skip it:
#'
#' * an **update** is done once applying it to `main` would change nothing —
#'   its entry is already fully incorporated (the same predicate the sync uses
#'   to decide whether to commit);
#' * a **delete request** is done once its entry file is absent from `main` —
#'   the reviewed purge workflow has removed it.
#'
#' Stateless and idempotent — safe to run on every sync-PR merge and after a
#' purge completes.
#'
#' @inheritParams directory_sync_airtable
#' @return Character vector of marked record ids (invisibly).
#' @export
directory_mark_synced <- function(
  base_id = directory_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  directory_repo = "directory"
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }

  cli::cli_h2("Reconciling synced submissions")
  submissions <- directory_drop_synced(
    airtable_list_records(base_id, "submissions", api_key)
  )
  lookups <- directory_build_lookups(base_id, api_key)
  transformed <- Filter(
    Negate(is.null),
    lapply(submissions, directory_transform_record, lookups = lookups)
  )

  handled <- Filter(
    function(entry) {
      if (isTRUE(entry$delete)) {
        directory_entry_absent(entry$slug, org, directory_repo)
      } else {
        directory_entry_incorporated(entry, org, directory_repo)
      }
    },
    transformed
  )
  record_ids <- vapply(
    handled,
    function(e) e$record_id %||% NA_character_,
    character(1)
  )
  record_ids <- unique(record_ids[!is.na(record_ids) & nzchar(record_ids)])

  airtable_mark_processed(base_id, "submissions", record_ids, api_key)
  cli::cli_alert_success(
    "Marked {length(record_ids)} submission{?s} as synced"
  )
  invisible(record_ids)
}

#' Is a submission already fully present on `main`?
#'
#' True when applying the submission would produce no change at all — entry,
#' photo, and contact all already reflect it (the same predicate the sync uses
#' to decide whether to commit). Checking only the entry file would flag a
#' submission whose sole pending change is the email or photo as done before
#' that change lands, dropping it.
#' @keywords internal
directory_entry_incorporated <- function(entry, org, repo, ref = "main") {
  length(directory_entry_changes(entry, org, repo, ref)) == 0L
}

#' Erase every Airtable submission for the given directory slugs.
#'
#' GDPR right-to-erasure: after the purge workflow removes a member's entry from
#' the directory, every `submissions` row that resolves to one of `slugs` (by
#' `directory_id`, falling back to `identifier`) is **deleted** from Airtable so
#' no submitted PII remains — and so a later sync cannot re-create the entry
#' from a leftover row. Unlike [directory_mark_synced()], which only flags the
#' `synced` checkbox, this destroys the rows.
#'
#' @param slugs Character vector of directory slugs to erase.
#' @param base_id Airtable base ID. Defaults to the directory base.
#' @param api_key Airtable API key. Defaults to the `AIRTABLE_API_KEY` env var.
#' @return Character vector of deleted record ids (invisibly).
#' @export
directory_purge_submissions <- function(
  slugs,
  base_id = directory_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }
  slugs <- unique(slugs[!is.na(slugs) & nzchar(slugs)])
  if (length(slugs) == 0) {
    cli::cli_alert_info("No slugs to purge")
    return(invisible(character(0)))
  }

  cli::cli_h2("Purging Airtable submissions for {length(slugs)} slug{?s}")
  submissions <- airtable_list_records(base_id, "submissions", api_key)
  matches <- Filter(
    function(r) {
      slug <- directory_slug(r$fields)
      !is.na(slug) && slug %in% slugs
    },
    submissions
  )
  record_ids <- vapply(
    matches,
    function(r) r$id %||% NA_character_,
    character(1)
  )
  record_ids <- unique(record_ids[!is.na(record_ids) & nzchar(record_ids)])

  airtable_delete_records(base_id, "submissions", record_ids, api_key)
  cli::cli_alert_success("Deleted {length(record_ids)} submission{?s}")
  invisible(record_ids)
}

#' Has a slug's entry file been removed from `main`?
#'
#' True only on a genuine 404 — the purge workflow has actioned the delete
#' request. Any other error (rate limit, network) propagates rather than being
#' read as "absent", so a flaky API call can never mark a delete request done
#' while the entry is still live.
#' @keywords internal
directory_entry_absent <- function(slug, org, repo, ref = "main") {
  path <- sprintf("data/json/%s.json", slug)
  tryCatch(
    {
      gh::gh(
        "GET /repos/{owner}/{repo}/contents/{path}",
        owner = org,
        repo = repo,
        path = path,
        ref = ref
      )
      FALSE
    },
    http_error_404 = function(e) TRUE
  )
}

#' Build id -> label lookups for the directory linked tables.
#' @keywords internal
directory_build_lookups <- function(base_id, api_key) {
  list(
    languages = directory_lookup(
      airtable_list_records(base_id, "languages", api_key),
      "Language"
    ),
    countries = directory_lookup(
      airtable_list_records(base_id, "countries", api_key),
      "Country"
    ),
    interests = directory_lookup(
      airtable_list_records(base_id, "interests", api_key),
      "interest"
    )
  )
}

#' Map Airtable record ids to a labelling field.
#' @keywords internal
directory_lookup <- function(records, label_field) {
  if (length(records) == 0) {
    return(stats::setNames(character(0), character(0)))
  }
  ids <- vapply(records, function(r) r$id %||% NA_character_, character(1))
  labels <- vapply(
    records,
    function(r) at_scalar(r$fields, label_field),
    character(1)
  )
  stats::setNames(labels, ids)
}

#' Transform a single Airtable submission into a directory entry.
#'
#' Returns `NULL` for ineligible records (default rows, non-minority-gender,
#' or missing a usable slug). Delete requests return early with just `slug`
#' and `delete = TRUE`. Otherwise returns a list with the target `slug`, the
#' submitted entry `data` (only fields the submitter provided), the `email`
#' for the contact file, `photo` download metadata, and `clear_fields`.
#' @keywords internal
directory_transform_record <- function(record, lookups) {
  fields <- record$fields
  if (identical(at_scalar(fields, "status"), "DEFAULT ROW")) {
    return(NULL)
  }
  if (!identical(at_scalar(fields, "minority_gender"), "yes")) {
    return(NULL)
  }

  slug <- directory_slug(fields)
  if (is.na(slug) || !nzchar(slug)) {
    return(NULL)
  }

  if (identical(at_scalar(fields, "request_type"), "Delete directory entry")) {
    return(list(slug = slug, record_id = record$id, delete = TRUE))
  }

  list(
    slug = slug,
    record_id = record$id,
    data = directory_entry_data(record, fields, lookups, slug),
    email = na_to_null(at_scalar(fields, "email")),
    photo = directory_photo_meta(fields),
    clear_fields = at_vector(fields, "clear_fields"),
    delete = FALSE
  )
}

#' Assemble the entry data list a submission contributes.
#' @keywords internal
directory_entry_data <- function(record, fields, lookups, slug) {
  data <- list()

  name <- punct_name(directory_full_name(fields))
  if (nzchar(name)) {
    data$name <- name
  }

  data$honorific <- na_to_null(at_scalar(fields, "honorific"))
  data$bio <- na_to_null(at_scalar(fields, "bio"))
  data$pronouns <- na_to_null(at_scalar(fields, "pronouns"))

  speaker <- at_scalar(fields, "speaker")
  if (!is.na(speaker)) {
    data$speaker <- identical(speaker, "Yes")
  }
  if (isTRUE(fields[["featured"]])) {
    data$featured <- TRUE
  }

  contact <- at_vector(fields, "contact")
  if (length(contact)) {
    data$contact_method <- as.list(contact)
  }

  interests <- resolve_links(fields[["interests"]], lookups$interests)
  if (length(interests)) {
    data$interests <- as.list(interests)
  }

  languages <- resolve_links(fields[["languages"]], lookups$languages)
  languages <- stringr::str_squish(languages)
  languages <- languages[nzchar(languages)]
  if (length(languages)) {
    data$languages <- as.list(languages)
  }

  social <- directory_social(fields)
  if (length(social)) {
    data$social_media <- social
  }

  work <- directory_prefixed(fields, "work_")
  if (length(work)) {
    data$work <- work
  }

  location <- directory_location(fields, lookups$countries)
  if (length(location)) {
    data$location <- location
  }

  r_groups <- directory_r_groups(fields)
  if (length(r_groups)) {
    data$activities <- list(r_groups = r_groups)
  }

  last_updated <- record$createdTime %||% NA_character_
  if (!is.na(last_updated)) {
    data$last_updated <- substr(last_updated, 1, 10)
  }
  data$identifier <- slug

  compact(data)
}

#' Join first and last name.
#' @keywords internal
directory_full_name <- function(fields) {
  parts <- c(at_scalar(fields, "first_name"), at_scalar(fields, "last_name"))
  parts <- parts[!is.na(parts) & nzchar(parts)]
  paste(parts, collapse = " ")
}

#' Slug from `directory_id`, falling back to `identifier`, cleaned to ASCII.
#' @keywords internal
directory_slug <- function(fields) {
  raw <- at_scalar(fields, "directory_id")
  if (is.na(raw) || !nzchar(raw)) {
    raw <- at_scalar(fields, "identifier")
  }
  if (is.na(raw) || !nzchar(raw)) {
    return(NA_character_)
  }
  clean <- stringi::stri_trans_general(raw, "Latin-ASCII")
  clean <- gsub("[^[:alpha:]-]", "", clean)
  clean <- gsub("-{2,}", "-", clean)
  clean <- tolower(clean)
  clean <- gsub("^-|-$", "", clean)
  if (!nzchar(clean)) {
    return(NA_character_)
  }
  clean
}

#' Ensure slugs are unique within a sync batch by suffixing collisions.
#' @keywords internal
directory_dedupe_slugs <- function(entries) {
  if (length(entries) == 0) {
    return(entries)
  }
  slugs <- make.unique(
    vapply(entries, function(e) e$slug, character(1)),
    sep = "-"
  )
  Map(
    function(entry, slug) {
      entry$slug <- slug
      entry$data$identifier <- slug
      entry
    },
    entries,
    slugs
  )
}

#' Field -> normaliser map for the `some_*` social handles.
#' @keywords internal
directory_social_normalizers <- function() {
  list(
    twitter = normalize_twitter,
    linkedin = normalize_linkedin,
    github = normalize_github,
    bluesky = normalize_bluesky,
    mastodon = normalize_mastodon
  )
}

#' Build the `social_media` object from `some_*` fields, normalised.
#' @keywords internal
directory_social <- function(fields) {
  raw <- directory_prefixed(fields, "some_")
  normalizers <- directory_social_normalizers()
  for (key in intersect(names(normalizers), names(raw))) {
    raw[[key]] <- normalizers[[key]](raw[[key]])
  }
  compact(raw)
}

#' Build the `location` object, resolving the linked country label.
#'
#' `directory_prefixed` would otherwise leave the raw `location_country` link
#' id under `country`, so it is dropped and replaced with the resolved label.
#' @keywords internal
directory_location <- function(fields, country_lookup) {
  loc <- directory_prefixed(fields, "location_")
  loc$country <- NULL
  country <- resolve_links(fields[["location_country"]], country_lookup)
  if (length(country)) {
    loc$country <- country[[1]]
  }
  compact(loc)
}

#' Collapse `<prefix>*` scalar fields into a named list without the prefix.
#' @keywords internal
directory_prefixed <- function(fields, prefix) {
  keys <- grep(paste0("^", prefix), names(fields), value = TRUE)
  vals <- vapply(keys, function(key) at_scalar(fields, key), character(1))
  keep <- !is.na(vals) & nzchar(vals)
  stats::setNames(
    as.list(unname(vals[keep])),
    sub(paste0("^", prefix), "", keys[keep])
  )
}

#' Build the `r_groups` name -> url map from `rgroup_name_*`/`rgroup_url_*`.
#' @keywords internal
directory_r_groups <- function(fields) {
  name_keys <- grep("^rgroup_name_", names(fields), value = TRUE)
  out <- list()
  for (name_key in name_keys) {
    idx <- sub("^rgroup_name_", "", name_key)
    group <- at_scalar(fields, name_key)
    if (is.na(group) || !nzchar(group)) {
      next
    }
    url <- at_scalar(fields, paste0("rgroup_url_", idx))
    out[[group]] <- if (is.na(url)) "" else url
  }
  out
}

#' Extract photo download metadata (url, extension, credit) from a submission.
#' @keywords internal
directory_photo_meta <- function(fields) {
  attachment <- fields[["photo_file"]]
  if (is.null(attachment) || length(attachment) == 0) {
    return(NULL)
  }
  photo <- attachment[[1]]
  if (is.null(photo$url)) {
    return(NULL)
  }
  list(
    url = photo$url,
    ext = directory_photo_ext(photo$type),
    credit = na_to_null(at_scalar(fields, "photo_credit"))
  )
}

#' Derive a safe file extension from an attachment MIME type.
#'
#' Reduces to the alphanumeric MIME subtype (e.g. `image/jpeg` -> `jpeg`),
#' falling back to `png`. Guarantees the extension cannot carry path
#' separators or other unexpected characters into the written file path.
#' @keywords internal
directory_photo_ext <- function(type) {
  ext <- gsub("[^a-z0-9]", "", sub(".*/", "", tolower(type %||% "")))
  if (!nzchar(ext)) {
    return("png")
  }
  ext
}

#' Append a period to single-character words in a name.
#' @keywords internal
punct_name <- function(x) {
  if (!is.character(x) || length(x) == 0) {
    return("")
  }
  vapply(
    strsplit(x, " ", fixed = TRUE),
    function(words) {
      words <- ifelse(nchar(words) == 1, paste0(words, "."), words)
      paste(words, collapse = " ")
    },
    character(1)
  )
}

#' Strip a leading `@` and the given URL prefixes, then lowercase.
#' @keywords internal
strip_handle_prefixes <- function(x, prefixes) {
  if (is_blank(x)) {
    return(NA_character_)
  }
  x <- sub("^@", "", x)
  for (prefix in prefixes) {
    x <- sub(prefix, "", x)
  }
  x <- tolower(trimws(x))
  if (!nzchar(x)) {
    return(NA_character_)
  }
  x
}

#' Normalise a Twitter/X handle to a bare lowercase username.
#' @keywords internal
normalize_twitter <- function(x) {
  strip_handle_prefixes(
    x,
    c("^https?://(www\\.)?twitter\\.com/", "^https?://(www\\.)?x\\.com/")
  )
}

#' Normalise a LinkedIn handle to a bare lowercase username.
#' @keywords internal
normalize_linkedin <- function(x) {
  strip_handle_prefixes(x, "^https?://(www\\.)?linkedin\\.com/in/")
}

#' Normalise a GitHub handle to a bare lowercase username.
#' @keywords internal
normalize_github <- function(x) {
  strip_handle_prefixes(x, "^https?://(www\\.)?github\\.com/")
}

#' Normalise a Bluesky handle to a bare lowercase handle.
#' @keywords internal
normalize_bluesky <- function(x) {
  strip_handle_prefixes(x, "^https?://(www\\.)?bsky\\.app/profile/")
}

#' Normalise a Mastodon profile URL to `@user@instance` handle form.
#' @keywords internal
normalize_mastodon <- function(x) {
  if (is_blank(x) || !grepl("^http", x) || !grepl("@", x)) {
    return(NA_character_)
  }
  sub("https?://([^/]+)/@([^/]+)", "@\\2@\\1", x)
}

#' Resolve a vector of Airtable link ids to their looked-up labels.
#' @keywords internal
resolve_links <- function(ids, lookup) {
  ids <- as.character(unlist(ids, use.names = FALSE))
  if (length(ids) == 0) {
    return(character(0))
  }
  out <- unname(lookup[ids])
  out[!is.na(out) & nzchar(out)]
}

#' Read a scalar Airtable field as a length-1 character (NA if absent).
#' @keywords internal
at_scalar <- function(fields, key) {
  val <- fields[[key]]
  if (is.null(val)) {
    return(NA_character_)
  }
  val <- unlist(val, use.names = FALSE)
  if (length(val) == 0) {
    return(NA_character_)
  }
  as.character(val[[1]])
}

#' Read a multi-value Airtable field as a character vector.
#' @keywords internal
at_vector <- function(fields, key) {
  val <- fields[[key]]
  if (is.null(val)) {
    return(character(0))
  }
  val <- as.character(unlist(val, use.names = FALSE))
  val[!is.na(val) & nzchar(val)]
}

na_to_null <- function(x) if (length(x) == 1 && is.na(x)) NULL else x

compact <- function(x) {
  Filter(
    function(v) {
      !is.null(v) &&
        length(v) > 0 &&
        !(is.atomic(v) && length(v) == 1 && is.na(v))
    },
    x
  )
}
