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
check_chapter_health <- function(months = 12, org = "rladies",
                                 data_repo = "meetup_archive") {
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
    latest$last_event >= cutoff, "active", "inactive"
  )

  latest <- latest[order(-latest$months_inactive), ]
  row.names(latest) <- NULL

  n_inactive <- sum(latest$status == "inactive")
  cli::cli_alert_info(
    "Found {n_inactive} inactive chapter{?s} (no events in {months}+ months)"
  )
  latest
}
