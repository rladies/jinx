#' Airtable base holding directory submissions.
#'
#' The `submissions` table carries one row per directory form submission,
#' with linked `languages`, `countries`, and `interests` tables resolved
#' into human-readable labels during the sync.
#' @keywords internal
directory_base_id <- function() "appzYxePUruG9Nwyg"

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
  cli::cli_alert_info("Fetched {length(submissions)} submission{?s}")

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
#' or missing a usable slug). Otherwise returns a list with the target `slug`,
#' the submitted entry `data` (only fields the submitter provided), the
#' `email` for the contact file, `photo` download metadata, the requested
#' `clear_fields`, and a `delete` flag.
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

  request_type <- at_scalar(fields, "request_type")
  is_delete <- identical(request_type, "Delete directory entry")

  data <- directory_entry_data(record, fields, lookups, slug)

  list(
    slug = slug,
    data = data,
    email = na_to_null(at_scalar(fields, "email")),
    photo = directory_photo_meta(fields),
    clear_fields = at_vector(fields, "clear_fields"),
    delete = is_delete
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
  if (!nzchar(clean)) NA_character_ else clean
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
  for (i in seq_along(entries)) {
    entries[[i]]$slug <- slugs[[i]]
    entries[[i]]$data$identifier <- slugs[[i]]
  }
  entries
}

#' Build the `social_media` object from `some_*` fields, normalised.
#' @keywords internal
directory_social <- function(fields) {
  raw <- directory_prefixed(fields, "some_")
  if ("twitter" %in% names(raw)) {
    raw$twitter <- normalize_twitter(raw$twitter)
  }
  if ("linkedin" %in% names(raw)) {
    raw$linkedin <- normalize_linkedin(raw$linkedin)
  }
  if ("mastodon" %in% names(raw)) {
    raw$mastodon <- normalize_mastodon(raw$mastodon)
  }
  compact(raw)
}

#' Build the `location` object, resolving the linked country.
#' @keywords internal
directory_location <- function(fields, country_lookup) {
  loc <- directory_prefixed(fields, "location_")
  country <- resolve_links(fields[["location_country"]], country_lookup)
  if (length(country)) {
    loc$country <- country[[1]]
  } else {
    loc$country <- NULL
  }
  compact(loc)
}

#' Collapse `<prefix>*` scalar fields into a named list without the prefix.
#' @keywords internal
directory_prefixed <- function(fields, prefix) {
  keys <- grep(paste0("^", prefix), names(fields), value = TRUE)
  out <- list()
  for (key in keys) {
    val <- at_scalar(fields, key)
    if (!is.na(val) && nzchar(val)) {
      out[[sub(paste0("^", prefix), "", key)]] <- val
    }
  }
  out
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
  ext <- sub(".*/", "", photo$type %||% "")
  if (!nzchar(ext)) {
    ext <- "png"
  }
  list(
    url = photo$url,
    ext = ext,
    credit = na_to_null(at_scalar(fields, "photo_credit"))
  )
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

#' Normalise a Twitter/X handle to a bare lowercase username.
#' @keywords internal
normalize_twitter <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }
  x <- sub("^@", "", x)
  x <- sub("^https?://(www\\.)?twitter\\.com/", "", x)
  x <- sub("^https?://(www\\.)?x\\.com/", "", x)
  x <- tolower(trimws(x))
  if (nzchar(x)) x else NA_character_
}

#' Normalise a LinkedIn handle to a bare lowercase username.
#' @keywords internal
normalize_linkedin <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }
  x <- sub("^https?://(www\\.)?linkedin\\.com/in/", "", x)
  x <- tolower(trimws(x))
  if (nzchar(x)) x else NA_character_
}

#' Normalise a Mastodon profile URL to `@user@instance` handle form.
#' @keywords internal
normalize_mastodon <- function(x) {
  if (is.null(x) || is.na(x) || !grepl("^http", x) || !grepl("@", x)) {
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
