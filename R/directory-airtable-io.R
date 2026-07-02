#' Write changed directory entries to the directory repo (in memory).
#'
#' For each submission, fetches the existing entry (if any), merges the
#' submission onto it (clearing requested fields first), and records a file
#' change only when the resulting content differs. Contact emails and profile
#' photos are handled alongside the entry JSON. Returns a list of pending file
#' changes for [directory_create_pr()] to commit.
#' @keywords internal
directory_write_entries <- function(entries, org, repo, ref = "main") {
  changes <- list()

  for (entry in entries) {
    slug <- entry$slug
    json_path <- sprintf("data/json/%s.json", slug)
    existing_obj <- gh_get_content(org, repo, json_path, ref)
    existing <- if (!is.null(existing_obj)) {
      jsonlite::fromJSON(
        rawToChar(jsonlite::base64_dec(existing_obj$content)),
        simplifyVector = FALSE
      )
    }

    data <- entry$data
    if (!is.null(entry$photo)) {
      photo <- directory_photo_change(entry, org, repo, ref)
      data$photo <- photo$meta
      if (!is.null(photo$change)) {
        changes <- c(changes, list(photo$change))
      }
    }

    final <- if (!is.null(existing)) {
      directory_merge(existing, data, entry$clear_fields)
    } else {
      data
    }

    if (
      is.null(existing) ||
        directory_fingerprint(final) != directory_fingerprint(existing)
    ) {
      changes <- c(
        changes,
        list(list(
          path = json_path,
          text = directory_to_json(final),
          sha = existing_obj$sha,
          kind = "entry",
          slug = slug
        ))
      )
    }

    if (!is.null(entry$email)) {
      contact <- directory_contact_change(slug, entry$email, org, repo, ref)
      if (!is.null(contact)) {
        changes <- c(changes, list(contact))
      }
    }
  }

  changes
}

#' Fields the form may wipe via `clear_fields`. `name` is intentionally absent.
#' @keywords internal
directory_clearable_fields <- function() {
  c(
    "bio",
    "pronouns",
    "honorific",
    "contact_method",
    "location",
    "social_media",
    "work",
    "interests",
    "languages",
    "activities",
    "photo"
  )
}

#' Merge a submission onto an existing entry: clear listed fields, then overlay.
#' @keywords internal
directory_merge <- function(existing, data, clear_fields = character(0)) {
  for (f in intersect(clear_fields, directory_clearable_fields())) {
    existing[[f]] <- NULL
  }
  directory_overlay(existing, data)
}

#' Deep-merge `source` onto `target`, per-subkey for nested objects.
#' @keywords internal
directory_overlay <- function(target, source) {
  nested_keys <- c("location", "work", "social_media")
  for (key in names(source)) {
    val <- source[[key]]
    if (is.null(val)) {
      next
    }
    if (key %in% nested_keys && is.list(target[[key]]) && is.list(val)) {
      for (sub in names(val)) {
        if (is.null(val[[sub]])) {
          next
        }
        target[[key]][[sub]] <- val[[sub]]
      }
    } else {
      target[[key]] <- val
    }
  }
  target
}

#' Order-independent, empty-insensitive content fingerprint for comparison.
#' @keywords internal
directory_fingerprint <- function(x) {
  as.character(jsonlite::toJSON(
    directory_sort(x),
    auto_unbox = TRUE,
    null = "null"
  ))
}

#' Recursively drop empty children and sort named lists for stable comparison.
#' @keywords internal
directory_sort <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  x <- lapply(x, directory_sort)
  x <- Filter(function(v) !is.null(v) && length(v) > 0, x)
  nms <- names(x)
  if (!is.null(nms) && all(nzchar(nms))) {
    x <- x[order(nms)]
  }
  x
}

#' Serialise an entry to the directory's pretty JSON form.
#' @keywords internal
directory_to_json <- function(x) {
  paste0(
    as.character(jsonlite::toJSON(
      x,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    )),
    "\n"
  )
}

#' Resolve a photo download into a file change plus the entry `photo` metadata.
#' @keywords internal
directory_photo_change <- function(entry, org, repo, ref) {
  slug <- entry$slug
  meta <- entry$photo
  img_path <- sprintf("data/img/%s.%s", slug, meta$ext)

  photo_meta <- list(url = sprintf("directory/%s.%s", slug, meta$ext))
  if (!is.null(meta$credit)) {
    photo_meta$credit <- meta$credit
  }

  bytes <- tryCatch(
    httr2::request(meta$url) |>
      httr2::req_timeout(30) |>
      httr2::req_perform() |>
      httr2::resp_body_raw(),
    error = function(e) {
      cli::cli_alert_warning("Failed to fetch photo for {slug}: {e$message}")
      NULL
    }
  )
  if (is.null(bytes)) {
    return(list(meta = photo_meta, change = NULL))
  }

  existing_obj <- gh_get_content(org, repo, img_path, ref)
  if (!is.null(existing_obj)) {
    existing_raw <- jsonlite::base64_dec(existing_obj$content)
    if (identical(as.integer(existing_raw), as.integer(bytes))) {
      return(list(meta = photo_meta, change = NULL))
    }
  }

  list(
    meta = photo_meta,
    change = list(
      path = img_path,
      raw = bytes,
      sha = existing_obj$sha,
      kind = "image",
      slug = slug
    )
  )
}

#' Resolve a contact email into a file change, or `NULL` if unchanged.
#' @keywords internal
directory_contact_change <- function(slug, email, org, repo, ref) {
  path <- sprintf("contact/%s.json", slug)
  payload <- stats::setNames(list(email), slug)
  existing_obj <- gh_get_content(org, repo, path, ref)

  if (!is.null(existing_obj)) {
    existing <- jsonlite::fromJSON(
      rawToChar(jsonlite::base64_dec(existing_obj$content)),
      simplifyVector = FALSE
    )
    if (directory_fingerprint(existing) == directory_fingerprint(payload)) {
      return(NULL)
    }
  }

  list(
    path = path,
    text = directory_to_json(payload),
    sha = existing_obj$sha,
    kind = "contact",
    slug = slug
  )
}

#' GET a repo file's contents object, or `NULL` if it does not exist.
#' @keywords internal
gh_get_content <- function(org, repo, path, ref = "main") {
  tryCatch(
    gh::gh(
      "GET /repos/{owner}/{repo}/contents/{path}",
      owner = org,
      repo = repo,
      path = path,
      ref = ref
    ),
    error = function(e) NULL
  )
}

#' Commit recorded changes to a sync branch and open (or reuse) a PR.
#' @keywords internal
directory_create_pr <- function(changes, deletes, org, repo, base = "main") {
  if (length(changes) == 0 && length(deletes) == 0) {
    return(invisible(NULL))
  }

  branch <- paste0("jinx/airtable-sync-", format(Sys.Date(), "%Y%m%d"))
  gh_branch_upsert(org, repo, branch, base = base)

  for (change in changes) {
    content <- if (identical(change$kind, "image")) {
      jsonlite::base64_enc(change$raw)
    } else {
      jsonlite::base64_enc(charToRaw(change$text))
    }
    params <- list(
      owner = org,
      repo = repo,
      path = change$path,
      message = glue::glue("Sync {change$path} from Airtable"),
      content = content,
      branch = branch
    )
    if (!is.null(change$sha)) {
      params$sha <- change$sha
    }
    do.call(gh::gh, c("PUT /repos/{owner}/{repo}/contents/{path}", params))
  }

  gh_open_or_update_pr(
    org,
    repo,
    branch,
    base = base,
    title = glue::glue("Airtable directory sync - {Sys.Date()}"),
    body = directory_pr_body(changes, deletes)
  )
}

#' Compose the sync PR body summarising changes and delete requests.
#' @keywords internal
directory_pr_body <- function(changes, deletes) {
  entries <- unique(vapply(
    Filter(function(c) identical(c$kind, "entry"), changes),
    function(c) c$slug,
    character(1)
  ))
  images <- sum(vapply(
    changes,
    function(c) identical(c$kind, "image"),
    logical(1)
  ))
  contacts <- sum(vapply(
    changes,
    function(c) identical(c$kind, "contact"),
    logical(1)
  ))

  lines <- c(
    "Automated sync of directory entries from Airtable.",
    "",
    glue::glue("- **Entries changed**: {length(entries)}"),
    glue::glue("- **Photos updated**: {images}"),
    glue::glue("- **Contacts updated**: {contacts}")
  )

  if (length(deletes) > 0) {
    del_slugs <- vapply(deletes, function(d) d$slug, character(1))
    lines <- c(
      lines,
      "",
      glue::glue(
        "{length(del_slugs)} delete request{?s} were submitted and need the ",
        "reviewed purge workflow: {paste(del_slugs, collapse = ', ')}"
      )
    )
  }

  lines <- c(lines, "", "_Created by jinx_")
  paste(lines, collapse = "\n")
}
