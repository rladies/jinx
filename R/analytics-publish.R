#' Generate analytics dashboard
#'
#' Orchestrates data collection, trend computation, and formatting.
#'
#' @param org GitHub organization.
#' @param months Number of months of history.
#' @param output_path Optional path to write JSON data.
#' @return Named list with `trends`, `growth`, and `markdown` (invisibly).
#' @export
generate_analytics_dashboard <- function(
  org = "rladies",
  months = 12,
  output_path = NULL
) {
  activity <- collect_chapter_activity(org = org, months = months)
  growth <- collect_contributor_growth(org = org, months = months)
  trends <- compute_activity_trends(activity)
  markdown <- format_analytics_markdown(trends, growth)

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

#' Publish analytics dashboard as a GitHub issue
#'
#' @param dashboard_data Data from [generate_analytics_dashboard()].
#' @param org GitHub organization.
#' @param target_repo Repository to publish to.
#' @param slack_channel Optional Slack channel to post a summary to.
#' @return Issue URL (invisibly).
#' @export
publish_analytics_dashboard <- function(
  dashboard_data,
  org = "rladies",
  target_repo = "global-team",
  slack_channel = NULL
) {
  body <- dashboard_data$markdown %||% "No analytics data available."

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = target_repo,
    title = cli::format_inline("Analytics Dashboard - {Sys.Date()}"),
    body = body,
    labels = list("report", "analytics")
  )

  cli::cli_alert_success("Analytics dashboard published: {issue$html_url}")

  if (!is.null(slack_channel)) {
    slack_body <- format_analytics_slack(dashboard_data, issue$html_url)
    post_slack_message(slack_body, channel = slack_channel)
  }

  invisible(issue$html_url)
}

format_analytics_slack <- function(dashboard_data, issue_url) {
  trends <- dashboard_data$trends
  growth <- dashboard_data$growth

  lines <- character(0)
  lines <- c(lines, glue::glue(":bar_chart: *Analytics Dashboard - {Sys.Date()}*"))

  if (nrow(trends) > 0) {
    total <- sum(trends$total_commits)
    latest <- trends$total_commits[nrow(trends)]
    sparkline <- paste(trends$sparkline, collapse = "")
    lines <- c(lines, "", glue::glue("Commits: *{total}* total ({latest} last month) {sparkline}"))
  }

  if (nrow(growth) > 0) {
    latest_g <- growth[nrow(growth), ]
    lines <- c(lines, glue::glue(
      "Contributors: *{latest_g$total_contributors}* total ({latest_g$new_contributors} new)"
    ))
  }

  lines <- c(lines, "", glue::glue("<{issue_url}|View full report>"))
  paste(lines, collapse = "\n")
}
