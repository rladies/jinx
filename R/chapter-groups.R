#' The Meetup group for one chapter entry
#'
#' Prefers `urlname` and falls back to `social_media$meetup`. Both are
#' present for almost every chapter, but they disagree for a handful, and
#' two chapters carry only the social one - so neither field alone is
#' sufficient and the order matters.
#'
#' @param entry Parsed chapter JSON.
#' @return A one-row data frame, or `NULL` when the chapter has no group.
#' @keywords internal
#' @noRd
chapter_group_row <- function(entry) {
  urlname <- entry$urlname %or% NULL
  social <- (entry$social_media %or% list())$meetup %or% NULL

  if (is.null(urlname) && is.null(social)) {
    return(NULL)
  }
  if (!is.null(urlname) && !is.null(social) && !identical(urlname, social)) {
    cli::cli_alert_warning(
      "{entry$file %or% 'a chapter'}: urlname {.val {urlname}} and
       social_media.meetup {.val {social}} disagree; using urlname"
    )
  }

  data.frame(
    file = entry$file %or% NA_character_,
    city = entry$city %or% NA_character_,
    country = entry$country %or% NA_character_,
    status = entry$status %or% NA_character_,
    urlname = urlname %or% social,
    stringsAsFactors = FALSE
  )
}

#' Chapters that have a Meetup group, read from the website data
#'
#' The website's `data/chapters` entries are the source of truth for
#' which chapters exist and which Meetup group each uses, so the sync
#' derives its list from there rather than from a hand-maintained one
#' that would drift the day it was written.
#'
#' Retired chapters are excluded by default: they have no upcoming events
#' and querying them only spends requests.
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param website_repo Repository holding `data/chapters`.
#' @param statuses Chapter statuses to include.
#' @return A data frame with columns `file`, `city`, `country`,
#'   `status`, and `urlname`.
#' @export
chapter_meetup_groups <- function(
  org = "rladies",
  website_repo = "rladies.github.io",
  statuses = c("active", "prospective")
) {
  files <- chapter_index_fetch(org, website_repo)
  cli::cli_alert_info("Reading {length(files)} chapter entries")

  entries <- lapply(files, function(file) {
    chapter_entry_fetch(file, org = org, repo = website_repo)
  })
  entries <- Filter(Negate(is.null), entries)

  rows <- Filter(Negate(is.null), lapply(entries, chapter_group_row))
  if (length(rows) == 0) {
    return(chapter_groups_empty())
  }

  groups <- do.call(rbind, rows)
  groups <- groups[groups$status %in% statuses, ]
  groups <- groups[!is.na(groups$urlname) & nzchar(groups$urlname), ]
  row.names(groups) <- NULL

  cli::cli_alert_success(
    "{nrow(groups)} chapter{?s} with a Meetup group ({toString(statuses)})"
  )
  groups
}

chapter_groups_empty <- function() {
  data.frame(
    file = character(0),
    city = character(0),
    country = character(0),
    status = character(0),
    urlname = character(0),
    stringsAsFactors = FALSE
  )
}
