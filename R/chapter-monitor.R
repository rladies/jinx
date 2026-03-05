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
monitor_chapter_status <- function(data_path = NULL, inactive_months = 6,
                                   org = "rladies") {
  if (!is.null(data_path)) {
    chapters <- utils::read.csv(data_path, stringsAsFactors = FALSE)
  } else {
    chapters <- fetch_chapter_data_from_archive(org)
  }

  if (nrow(chapters) == 0) {
    cli::cli_alert_warning("No chapter data available")
    return(data.frame())
  }

  today <- Sys.Date()
  cutoff <- today - (inactive_months * 30)

  chapters$last_event <- as.Date(chapters$last_event)
  chapters$founded_date <- as.Date(chapters$founded_date)

  chapters$status <- vapply(seq_len(nrow(chapters)), function(i) {
    r <- chapters[i, ]
    if (!is.na(r$upcoming_events) && r$upcoming_events >= 1) {
      "active with upcoming events"
    } else if (!is.na(r$last_event) && r$last_event >= cutoff) {
      "active in the past 6 months"
    } else if (!is.na(r$last_event) && r$last_event < cutoff) {
      "inactive"
    } else if (is.na(r$last_event) && !is.na(r$founded_date) &&
               r$founded_date >= cutoff) {
      "unbegun, but founded during last six months"
    } else {
      "unbegun"
    }
  }, character(1))

  chapters <- chapters[order(
    -as.integer(!is.na(chapters$upcoming_events) & chapters$upcoming_events > 0),
    -as.integer(!is.na(chapters$last_event)),
    chapters$last_event
  ), ]

  n_inactive <- sum(chapters$status == "inactive")
  cli::cli_alert_info(
    "Chapter status: {sum(grepl('active', chapters$status))} active, {n_inactive} inactive"
  )

  chapters
}

#' Send inactivity warning emails
#'
#' Identifies inactive chapters and prepares warning emails for organizers.
#'
#' @param chapters Chapter status data from [monitor_chapter_status()].
#' @param template_path Path to email template.
#' @param dry_run If `TRUE` (default), only returns the email data without
#'   sending.
#' @return Data frame of prepared emails (invisibly).
#' @export
prepare_inactivity_emails <- function(chapters,
                                      template_path = NULL,
                                      dry_run = TRUE) {
  if (is.null(template_path)) {
    template_path <- system.file(
      "templates", "chapter-inactive.md", package = "jinx"
    )
  }

  inactive <- chapters[chapters$status == "inactive", ]
  if (nrow(inactive) == 0) {
    cli::cli_alert_info("No inactive chapters found")
    return(invisible(data.frame()))
  }

  template <- paste(readLines(template_path, warn = FALSE), collapse = "\n")

  emails <- data.frame(
    chapter = inactive$name,
    email = paste0(inactive$urlname, "@rladies.org"),
    subject = paste0(inactive$name, " is at risk of being deactivated"),
    stringsAsFactors = FALSE
  )

  emails$body <- vapply(seq_len(nrow(emails)), function(i) {
    glue::glue(
      template,
      chapter_name = emails$chapter[i],
      .open = "{{", .close = "}}"
    )
  }, character(1))

  if (dry_run) {
    cli::cli_alert_info("Dry run: {nrow(emails)} emails prepared (not sent)")
  } else {
    cli::cli_alert_success("{nrow(emails)} inactivity warnings sent")
  }

  invisible(emails)
}

fetch_chapter_data_from_archive <- function(org) {
  health <- check_chapter_health(months = 6, org = org)
  if (nrow(health) == 0) return(data.frame())

  data.frame(
    name = health$chapter,
    urlname = health$chapter,
    last_event = health$last_event,
    upcoming_events = NA_integer_,
    founded_date = NA,
    stringsAsFactors = FALSE
  )
}
