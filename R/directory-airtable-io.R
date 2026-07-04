#' Write changed directory entries to the directory repo (in memory).
#'
#' For each submission, fetches the existing entry (if any), merges the
#' submission onto it (clearing requested fields first), and records a file
#' change only when the resulting content differs. Contact emails and profile
#' photos are handled alongside the entry JSON. Returns a flat list of pending
#' file changes for [directory_create_pr()] to commit.
#' @keywords internal
directory_write_entries <- function(entries, org, repo, ref = "main") {
  per_entry <- lapply(
    entries,
    directory_entry_changes,
    org = org,
    repo = repo,
    ref = ref
  )
  unlist(per_entry, recursive = FALSE)
}

#' Compute the pending file changes for a single submission.
#' @keywords internal
directory_entry_changes <- function(entry, org, repo, ref) {
  slug <- entry$slug
  json_path <- sprintf("data/json/%s.json", slug)
  existing_obj <- gh_get_content(org, repo, json_path, ref)
  existing <- directory_decode_json(existing_obj)
  changes <- list()

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
  changes
}

#' Decode a GitHub contents object's base64 payload to a raw vector.
#'
#' The contents API wraps base64 at column 60 with newlines, which are
#' stripped before decoding.
#' @keywords internal
directory_decode_raw <- function(obj) {
  jsonlite::base64_dec(gsub("\n", "", obj$content, fixed = TRUE))
}

#' Decode a GitHub contents object into a parsed JSON list, or `NULL`.
#' @keywords internal
directory_decode_json <- function(obj) {
  if (is.null(obj)) {
    return(NULL)
  }
  jsonlite::fromJSON(
    rawToChar(directory_decode_raw(obj)),
    simplifyVector = FALSE
  )
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

#' Entry keys that are objects and merged per sub-key rather than replaced.
#' @keywords internal
directory_nested_keys <- function() {
  c("location", "work", "social_media", "activities")
}

#' Merge a submission onto an existing entry: clear listed fields, then overlay.
#' @keywords internal
directory_merge <- function(existing, data, clear_fields = character(0)) {
  existing[intersect(clear_fields, directory_clearable_fields())] <- NULL
  directory_overlay(existing, data)
}

#' Deep-merge `source` onto `target`, per-subkey for nested objects.
#' @keywords internal
directory_overlay <- function(target, source) {
  nested_keys <- directory_nested_keys()
  for (key in names(source)) {
    val <- source[[key]]
    if (is.null(val)) {
      next
    }
    target[[key]] <- if (key %in% nested_keys) {
      directory_merge_nested(target[[key]], val)
    } else {
      val
    }
  }
  target
}

#' Overlay a nested object's sub-keys, or replace wholesale if not both lists.
#' @keywords internal
directory_merge_nested <- function(target, val) {
  if (!is.list(target) || !is.list(val)) {
    return(val)
  }
  present <- val[!vapply(val, is.null, logical(1))]
  target[names(present)] <- present
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

#' Build the entry `photo` block (public url + optional credit).
#' @keywords internal
directory_photo_block <- function(slug, meta) {
  block <- list(url = sprintf("directory/%s.%s", slug, meta$ext))
  if (!is.null(meta$credit)) {
    block$credit <- meta$credit
  }
  block
}

#' Resolve a photo download into a file change plus the entry `photo` block.
#'
#' On download failure the entry `photo` is kept only if the image already
#' exists in the repo, so a failed fetch never leaves a dangling `photo.url`.
#' @keywords internal
directory_photo_change <- function(entry, org, repo, ref) {
  slug <- entry$slug
  meta <- entry$photo
  img_path <- sprintf("data/img/%s.%s", slug, meta$ext)
  existing_obj <- gh_get_content(org, repo, img_path, ref)

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
    meta_block <- if (is.null(existing_obj)) {
      NULL
    } else {
      directory_photo_block(slug, meta)
    }
    return(list(meta = meta_block, change = NULL))
  }

  photo_block <- directory_photo_block(slug, meta)
  if (
    !is.null(existing_obj) &&
      identical(directory_decode_raw(existing_obj), bytes)
  ) {
    return(list(meta = photo_block, change = NULL))
  }

  list(
    meta = photo_block,
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
  existing <- directory_decode_json(existing_obj)

  if (
    !is.null(existing) &&
      directory_fingerprint(existing) == directory_fingerprint(payload)
  ) {
    return(NULL)
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

#' Commit recorded changes as a single commit and open (or reuse) a PR.
#'
#' Uses the git data API (blobs -> tree -> commit -> ref) so the whole sync
#' lands as one commit, rather than one commit per file.
#' @keywords internal
directory_create_pr <- function(changes, deletes, org, repo, base = "main") {
  if (length(changes) == 0 && length(deletes) == 0) {
    return(invisible(NULL))
  }

  branch <- "jinx/airtable-sync"
  base_sha <- gh::gh(
    "GET /repos/{owner}/{repo}/git/ref/heads/{base}",
    owner = org,
    repo = repo,
    base = base
  )$object$sha
  base_tree <- gh::gh(
    "GET /repos/{owner}/{repo}/git/commits/{commit_sha}",
    owner = org,
    repo = repo,
    commit_sha = base_sha
  )$tree$sha

  tree <- lapply(changes, function(change) {
    raw <- if (identical(change$kind, "image")) {
      change$raw
    } else {
      charToRaw(change$text)
    }
    blob <- gh::gh(
      "POST /repos/{owner}/{repo}/git/blobs",
      owner = org,
      repo = repo,
      content = jsonlite::base64_enc(raw),
      encoding = "base64"
    )
    list(path = change$path, mode = "100644", type = "blob", sha = blob$sha)
  })

  new_tree <- gh::gh(
    "POST /repos/{owner}/{repo}/git/trees",
    owner = org,
    repo = repo,
    base_tree = base_tree,
    tree = tree
  )$sha
  commit_sha <- gh::gh(
    "POST /repos/{owner}/{repo}/git/commits",
    owner = org,
    repo = repo,
    message = directory_commit_message(changes),
    tree = new_tree,
    parents = list(base_sha)
  )$sha

  directory_set_branch(org, repo, branch, commit_sha)

  gh_open_or_update_pr(
    org,
    repo,
    branch,
    base = base,
    title = glue::glue("Airtable directory sync - {Sys.Date()}"),
    body = directory_pr_body(changes, deletes)
  )
}

#' Point a branch at a commit, creating the ref or force-updating it.
#' @keywords internal
directory_set_branch <- function(org, repo, branch, sha) {
  created <- tryCatch(
    {
      gh::gh(
        "POST /repos/{owner}/{repo}/git/refs",
        owner = org,
        repo = repo,
        ref = glue::glue("refs/heads/{branch}"),
        sha = sha
      )
      TRUE
    },
    error = function(e) FALSE
  )
  if (!created) {
    gh::gh(
      "PATCH /repos/{owner}/{repo}/git/refs/heads/{branch}",
      owner = org,
      repo = repo,
      branch = branch,
      sha = sha,
      force = TRUE
    )
  }
  invisible(sha)
}

#' One-line commit message summarising the number of changed entries.
#' @keywords internal
directory_commit_message <- function(changes) {
  n <- length(unique(vapply(
    Filter(function(ch) identical(ch$kind, "entry"), changes),
    function(ch) ch$slug,
    character(1)
  )))
  sprintf(
    "Sync %d directory %s from Airtable",
    n,
    if (n == 1) "entry" else "entries"
  )
}

#' Compose the sync PR body summarising changes and delete requests.
#' @keywords internal
directory_pr_body <- function(changes, deletes) {
  kinds <- vapply(changes, function(ch) ch$kind %||% "", character(1))
  slugs <- vapply(changes, function(ch) ch$slug %||% "", character(1))

  lines <- c(
    "Automated sync of directory entries from Airtable.",
    "",
    sprintf(
      "- **Entries changed**: %d",
      length(unique(slugs[kinds == "entry"]))
    ),
    sprintf("- **Photos updated**: %d", sum(kinds == "image")),
    sprintf("- **Contacts updated**: %d", sum(kinds == "contact"))
  )

  if (length(deletes) > 0) {
    del_slugs <- vapply(deletes, function(d) d$slug, character(1))
    lines <- c(
      lines,
      "",
      sprintf(
        paste(
          "%d delete request%s were submitted and need the reviewed purge",
          "workflow: %s"
        ),
        length(del_slugs),
        if (length(del_slugs) == 1) "" else "s",
        paste(del_slugs, collapse = ", ")
      )
    )
  }

  paste(c(lines, "", "_Created by jinx_"), collapse = "\n")
}
