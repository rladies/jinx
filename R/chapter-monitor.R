#' Monitor chapter activity status
#'
#' Determines chapter status based on meetup event data. Chapters are
#' classified as active, inactive, or unbegun based on their last event
#' and founding date.
#'
#' @param data_path Path to a CSV export from Meetup Pro Dashboard,
#'   or `NULL` to fetch from meetup_archive.
#' @param inactive_months Months without events to consider inactive.
#'   Defaults to 6.
#' @param org GitHub organization.
#' @return Data frame with chapter status information.
#' @export
chapter_monitor_status <- function(
  data_path = NULL,
  inactive_months = 6,
  org = "rladies"
) {
  if (!is.null(data_path)) {
    chapters <- utils::read.csv(data_path, stringsAsFactors = FALSE)
  } else {
    chapters <- chapter_fetch_archive_data(org)
  }

  if (nrow(chapters) == 0) {
    cli::cli_alert_warning("No chapter data available")
    return(data.frame())
  }

  today <- Sys.Date()
  cutoff <- today - (inactive_months * 30)

  chapters$last_event <- as.Date(chapters$last_event)
  chapters$founded_date <- as.Date(chapters$founded_date)

  chapters$status <- mapply(
    chapter_classify_status,
    chapters$upcoming_events,
    chapters$last_event,
    chapters$founded_date,
    MoreArgs = list(cutoff = cutoff),
    USE.NAMES = FALSE
  )

  chapters <- chapters[
    order(
      -as.integer(
        !is.na(chapters$upcoming_events) & chapters$upcoming_events > 0
      ),
      -as.integer(!is.na(chapters$last_event)),
      chapters$last_event
    ),
  ]

  n_inactive <- sum(chapters$status == "inactive")
  n_active <- sum(grepl("active", chapters$status, fixed = TRUE))
  cli::cli_alert_info(
    "Chapter status: {n_active} active, {n_inactive} inactive"
  )

  chapters
}

#' Prepare the guide's first inactivity notice for inactive chapters
#'
#' Identifies inactive chapters and prepares the notice the guide
#' documents for them. The wording and the subject line come from the
#' guide, fetched at call time, so the message organisers receive is the
#' one a volunteer can edit there.
#'
#' @param chapters Chapter status data from [chapter_monitor_status()].
#' @param template Name of the guide template to send. Defaults to the
#'   first inactivity notice; the guide also documents a retirement
#'   notice (`"chapter-retirement-scheduled"`) for chapters that do not
#'   reply.
#' @param dry_run Controls the wording of the summary only. Either way
#'   the prepared emails are returned rather than sent: delivery goes
#'   through [mail_send()], which a human still drives.
#' @return Data frame of prepared emails, one row per inactive chapter,
#'   with `chapter`, `email`, `subject` and `body` (invisibly).
#' @export
prepare_inactivity_emails <- function(
  chapters,
  template = "chapter-inactive-first-notice",
  dry_run = TRUE
) {
  inactive <- chapters[chapters$status == "inactive", ]
  if (nrow(inactive) == 0) {
    cli::cli_alert_info("No inactive chapters found")
    return(invisible(data.frame()))
  }

  notice <- guide_email_template(template)

  emails <- data.frame(
    chapter = inactive$name,
    email = paste0(inactive$urlname, "@rladies.org"),
    subject = notice$subject,
    body = notice$body,
    stringsAsFactors = FALSE
  )

  if (dry_run) {
    cli::cli_alert_info("Dry run: {nrow(emails)} emails prepared (not sent)")
  } else {
    cli::cli_alert_info(c(
      "{nrow(emails)} email{?s} prepared. jinx does not send these itself yet;",
      " pass each row to {.fn mail_send}."
    ))
  }

  invisible(emails)
}

chapter_classify_status <- function(upcoming, last, founded, cutoff) {
  if (isTRUE(upcoming >= 1)) {
    return("active with upcoming events")
  }
  if (isTRUE(last >= cutoff)) {
    return("active in the past 6 months")
  }
  if (isTRUE(last < cutoff)) {
    return("inactive")
  }
  if (isTRUE(founded >= cutoff)) {
    return("unbegun, but founded during last six months")
  }
  "unbegun"
}

chapter_fetch_archive_data <- function(org) {
  health <- chapter_check_health(months = 6, org = org)
  if (nrow(health) == 0) {
    return(data.frame())
  }

  data.frame(
    name = health$chapter,
    urlname = health$chapter,
    last_event = health$last_event,
    upcoming_events = NA_integer_,
    founded_date = NA,
    stringsAsFactors = FALSE
  )
}
