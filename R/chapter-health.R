#' Check chapter health across the organization
#'
#' Identifies chapters that have been inactive (no events) for a
#' specified number of months.
#'
#' @param months Number of months without activity to consider inactive.
#'   Defaults to 12.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param data_repo Repository containing chapter/event data.
#'   Defaults to `"meetup_archive"`.
#' @return A data frame with columns `chapter`, `last_event`, `status`,
#'   and `months_inactive`.
#' @export
chapter_check_health <- function(
  months = 12,
  org = "rladies",
  data_repo = "meetup_archive"
) {
  events_url <- glue::glue(
    "https://raw.githubusercontent.com/{org}/{data_repo}/main/data/events.json"
  )

  events <- tryCatch(
    jsonlite::fromJSON(events_url, simplifyDataFrame = TRUE),
    error = function(e) {
      cli::cli_alert_danger("Failed to fetch events data: {e$message}")
      return(data.frame())
    }
  )

  if (nrow(events) == 0) {
    cli::cli_alert_warning("No events data available")
    return(data.frame())
  }

  cutoff <- Sys.Date() - (months * 30)

  events$date <- as.Date(events$datetime)
  latest <- stats::aggregate(date ~ group_urlname, data = events, FUN = max)
  names(latest) <- c("chapter", "last_event")

  latest$months_inactive <- as.integer(
    difftime(Sys.Date(), latest$last_event, units = "days") / 30
  )
  latest$status <- ifelse(
    latest$last_event >= cutoff,
    "active",
    "inactive"
  )

  latest <- latest[order(-latest$months_inactive), ]
  row.names(latest) <- NULL

  n_inactive <- sum(latest$status == "inactive")
  cli::cli_alert_info(
    "Found {n_inactive} inactive chapter{?s} (no events in {months}+ months)"
  )
  latest
}

#' Summarise chapter health as chat markdown
#'
#' @param health A data frame from [chapter_check_health()].
#' @return Character string of markdown.
#' @keywords internal
#' @noRd
chapter_health_summary <- function(health) {
  if (nrow(health) == 0) {
    return("No chapter data available.")
  }
  inactive <- health[health$status == "inactive", ]
  if (nrow(inactive) == 0) {
    return(glue::glue("All {nrow(health)} chapters are active. \U0001f389"))
  }
  lines <- glue::glue_data(
    utils::head(inactive, 15),
    "- **{chapter}**: {months_inactive} months inactive",
    " (last event {last_event})"
  )
  paste0(
    "## Chapter health: ",
    nrow(inactive),
    " inactive chapter(s)\n\n",
    paste(lines, collapse = "\n")
  )
}
