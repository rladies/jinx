#' Generate analytics dashboard
#'
#' Orchestrates data collection, trend computation, and formatting.
#'
#' @param org GitHub organization.
#' @param months Number of months of history.
#' @param output_path Optional path to write JSON data.
#' @return Named list with `trends`, `growth`, and `markdown` (invisibly).
#' @export
analytics_generate_dashboard <- function(
  org = "rladies",
  months = 12,
  output_path = NULL
) {
  activity <- analytics_collect_chapter_activity(org = org, months = months)
  growth <- analytics_collect_contributor_growth(org = org, months = months)
  trends <- analytics_compute_trends(activity)
  markdown <- analytics_format_markdown(trends, growth)

  result <- list(
    trends = trends,
    growth = growth,
    markdown = markdown
  )

  if (!is.null(output_path)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(result, output_path, pretty = TRUE, auto_unbox = TRUE)
    cli::cli_alert_success("Analytics data written to {output_path}")
  }

  invisible(result)
}
