#' Post an automated directory review as a PR checklist comment
#'
#' Runs the checks that used to be manual review-checklist items on the
#' entry files changed in a PR (filenames, likely-duplicate slugs, contact
#' method vs. social entry, stray contact info in free text) and posts a
#' single consolidated checklist. Each entry lists clickable profile links
#' so reviewers can confirm the social accounts resolve, rather than an
#' unreliable automated check (the platforms block bot requests). Schema
#' validity is covered separately by the directory repo's JSON validation.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @return Invisibly `NULL`.
#' @export
validate_directory_pr <- function(owner, repo, pr_number) {
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
    directory_review_entry(entry, basename(f$filename))
  })

  announce_post_reply(owner, repo, pr_number, directory_review_format(reviews))
  cli::cli_alert_info("Posted directory review on PR #{pr_number}")
  invisible()
}

#' Run all automated review checks on a single directory entry.
#' @keywords internal
directory_review_entry <- function(entry, filename) {
  issues <- c(
    directory_filename_issues(filename),
    directory_collision_issue(filename)
  )
  if (is.null(entry)) {
    return(list(
      file = filename,
      issues = c(issues, "could not read entry content"),
      links = character(0)
    ))
  }

  issues <- c(
    issues,
    directory_contact_social_issues(entry),
    directory_sensitive_issues(entry)
  )
  list(
    file = filename,
    issues = issues,
    links = directory_profile_links(entry)
  )
}

#' Filename convention issues, prefixed for the report.
#' @keywords internal
directory_filename_issues <- function(filename) {
  check <- directory_validate_filename(filename)
  if (check$valid) {
    return(character(0))
  }
  paste("filename:", check$issues)
}

#' Flag a numeric-suffixed slug as a possible duplicate to merge.
#' @keywords internal
directory_collision_issue <- function(filename) {
  name <- sub("\\.json$", "", filename)
  if (!grepl("-[0-9]+$", name)) {
    return(character(0))
  }
  sprintf(
    paste(
      "\"%s\" has a numeric suffix - confirm this is a distinct person,",
      "not a duplicate to merge"
    ),
    name
  )
}

#' Flag contact methods that lack a matching `social_media` entry.
#' @keywords internal
directory_contact_social_issues <- function(entry) {
  methods <- unlist(entry$contact_method, use.names = FALSE)
  methods <- methods[!is.na(methods) & nzchar(methods)]
  methods <- methods[!tolower(methods) %in% c("email", "e-mail")]
  if (length(methods) == 0) {
    return(character(0))
  }
  social <- entry$social_media %||% list()
  keys <- tolower(methods)
  present <- vapply(
    keys,
    function(key) {
      value <- social[[key]]
      !is.null(value) && nzchar(as.character(value))
    },
    logical(1)
  )
  sprintf(
    "contact method \"%s\" but social_media.%s is empty",
    methods[!present],
    keys[!present]
  )
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
  if (!grepl("[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}", text)) {
    return(character(0))
  }
  "possible email address in free text (bio/work) - confirm it is not private"
}

#' Build a "Profiles" line of clickable social links for the reviewer.
#'
#' The social platforms block automated existence checks, so instead of an
#' unreliable HTTP probe the review offers ready-made links the reviewer can
#' click to confirm each account resolves.
#' @keywords internal
directory_profile_links <- function(entry) {
  social <- entry$social_media
  platforms <- names(social)
  if (length(platforms) == 0) {
    return(character(0))
  }
  urls <- vapply(
    platforms,
    function(platform) {
      handle <- social[[platform]]
      builder <- social_url_builders[[platform]]
      if (
        is.null(builder) || is.null(handle) || !nzchar(as.character(handle))
      ) {
        return(NA_character_)
      }
      tryCatch(builder(as.character(handle)), error = function(e) NA_character_)
    },
    character(1)
  )
  ok <- !is.na(urls) & nzchar(urls)
  if (!any(ok)) {
    return(character(0))
  }
  links <- sprintf("[%s](%s)", platforms[ok], urls[ok])
  paste0("Profiles (click to check): ", paste(links, collapse = " \u00b7 "))
}

#' Format the per-entry review results as a markdown PR checklist comment.
#'
#' Each entry is a task-list checkbox reviewers tick as they go, so progress
#' is visible at a glance; automated flags are shown under their entry.
#' @keywords internal
directory_review_format <- function(reviews) {
  total <- sum(vapply(reviews, function(r) length(r$issues), integer(1)))
  intro <- if (total == 0) {
    "Automated checks passed."
  } else {
    sprintf(
      "%d automated flag%s below (shown under the entry).",
      total,
      if (total == 1) "" else "s"
    )
  }
  header <- paste0(
    "### Directory sync - automated review\n\n",
    intro,
    " Tick each entry as you review it, and click its profile",
    " links to confirm they resolve."
  )

  blocks <- lapply(reviews, function(r) {
    sub <- c(
      if (length(r$links)) sprintf("  - %s", r$links),
      if (length(r$issues)) sprintf("  - %s", r$issues)
    )
    c(sprintf("- [ ] **%s**", r$file), sub)
  })
  lines <- unlist(blocks, use.names = FALSE)

  manual <- c(
    "**Before merging, confirm manually:**",
    "- [ ] Each person is a minority-gender person (name / image / context)",
    "- [ ] Photos crop to the right area (check the preview build)"
  )

  paste(c(header, "", lines, "", manual), collapse = "\n")
}
