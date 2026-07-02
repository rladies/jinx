#' Post an automated directory review as a PR comment
#'
#' Runs the checks that used to be manual review-checklist items on the
#' entry files changed in a PR (filenames, likely-duplicate slugs, contact
#' method vs. social entry, stray contact info in free text, and whether
#' social handles resolve) and posts a single consolidated report. Schema
#' validity is covered separately by the directory repo's JSON validation.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @param verify_handles Whether to HTTP-check that social handles resolve.
#'   Defaults to `TRUE`; set `FALSE` to skip the network calls.
#' @return Invisibly `NULL`.
#' @export
validate_directory_pr <- function(
  owner,
  repo,
  pr_number,
  verify_handles = TRUE
) {
  pr <- gh::gh(
    "GET /repos/{owner}/{repo}/pulls/{pr_number}",
    owner = owner,
    repo = repo,
    pr_number = pr_number
  )
  head_ref <- pr$head$sha

  files <- gh::gh(
    "GET /repos/{owner}/{repo}/pulls/{pr_number}/files",
    owner = owner,
    repo = repo,
    pr_number = pr_number,
    .limit = Inf
  )
  json_files <- Filter(
    function(f) {
      grepl("\\.json$", f$filename) &&
        grepl("^data/", f$filename) &&
        !identical(f$status, "removed")
    },
    files
  )

  if (length(json_files) == 0) {
    announce_post_reply(
      owner,
      repo,
      pr_number,
      "No directory entry files changed in this PR."
    )
    return(invisible())
  }

  reviews <- lapply(json_files, function(f) {
    entry <- directory_decode_json(gh_get_content(
      owner,
      repo,
      f$filename,
      head_ref
    ))
    directory_review_entry(
      entry,
      basename(f$filename),
      verify_handles = verify_handles
    )
  })

  announce_post_reply(owner, repo, pr_number, directory_review_format(reviews))
  cli::cli_alert_info("Posted directory review on PR #{pr_number}")
  invisible()
}

#' Run all automated review checks on a single directory entry.
#' @keywords internal
directory_review_entry <- function(entry, filename, verify_handles = TRUE) {
  issues <- c(
    directory_filename_issues(filename),
    directory_collision_issue(filename)
  )
  if (is.null(entry)) {
    return(list(
      file = filename,
      issues = c(issues, "could not read entry content")
    ))
  }

  issues <- c(
    issues,
    directory_contact_social_issues(entry),
    directory_sensitive_issues(entry)
  )
  if (verify_handles) {
    issues <- c(issues, directory_handle_issues(entry))
  }
  list(file = filename, issues = issues)
}

#' Filename convention issues, prefixed for the report.
#' @keywords internal
directory_filename_issues <- function(filename) {
  check <- directory_validate_filename(filename)
  if (check$valid) character(0) else paste("filename:", check$issues)
}

#' Flag a numeric-suffixed slug as a possible duplicate to merge.
#' @keywords internal
directory_collision_issue <- function(filename) {
  name <- sub("\\.json$", "", filename)
  if (grepl("-[0-9]+$", name)) {
    sprintf(
      paste(
        "\"%s\" has a numeric suffix - confirm this is a distinct person,",
        "not a duplicate to merge"
      ),
      name
    )
  } else {
    character(0)
  }
}

#' Flag contact methods that lack a matching `social_media` entry.
#' @keywords internal
directory_contact_social_issues <- function(entry) {
  methods <- unlist(entry$contact_method, use.names = FALSE)
  methods <- methods[!is.na(methods) & nzchar(methods)]
  social <- entry$social_media %||% list()
  issues <- character(0)
  for (method in methods) {
    key <- tolower(method)
    if (key %in% c("email", "e-mail")) {
      next
    }
    value <- social[[key]]
    if (is.null(value) || !nzchar(as.character(value))) {
      issues <- c(
        issues,
        sprintf(
          "contact method \"%s\" but social_media.%s is empty",
          method,
          key
        )
      )
    }
  }
  issues
}

#' Flag a stray email address in the entry's free-text fields.
#' @keywords internal
directory_sensitive_issues <- function(entry) {
  text <- paste(
    c(
      entry$bio,
      entry$work$title,
      entry$work$organisation,
      entry$work$organization
    ),
    collapse = " "
  )
  if (grepl("[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}", text)) {
    "possible email address in free text (bio/work) - confirm it is not private"
  } else {
    character(0)
  }
}

#' Flag social handles that do not resolve over HTTP.
#' @keywords internal
directory_handle_issues <- function(entry) {
  df <- tryCatch(directory_verify_handles(entry), error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) {
    return(character(0))
  }
  bad <- df[!is.na(df$valid) & !df$valid, , drop = FALSE]
  if (nrow(bad) == 0) {
    return(character(0))
  }
  sprintf(
    "%s handle \"%s\" may not resolve - verify the account exists",
    bad$platform,
    bad$handle
  )
}

#' Format the per-entry review results as a markdown PR comment.
#' @keywords internal
directory_review_format <- function(reviews) {
  total <- sum(vapply(reviews, function(r) length(r$issues), integer(1)))
  header <- if (total == 0) {
    "### Directory sync - automated review\n\n**All automated checks passed.**"
  } else {
    sprintf(
      "### Directory sync - automated review\n\n**%d item%s to review below.**",
      total,
      if (total == 1) "" else "s"
    )
  }

  lines <- character(0)
  for (r in reviews) {
    if (length(r$issues) == 0) {
      lines <- c(lines, sprintf("- **%s** - OK", r$file))
    } else {
      lines <- c(
        lines,
        sprintf("- **%s**", r$file),
        vapply(r$issues, function(i) sprintf("  - %s", i), character(1))
      )
    }
  }

  footer <- paste(
    "_Automated checks only. Still confirm manually: minority-gender",
    "eligibility, and that photos don't crop badly (see the preview build)._"
  )
  paste(c(header, "", lines, "", footer), collapse = "\n")
}
