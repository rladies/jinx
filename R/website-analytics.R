#' Collect website analytics from Plausible
#'
#' Queries the Plausible Analytics API for visitor and pageview metrics.
#'
#' @param site_id Plausible site ID (domain). Defaults to
#'   `Sys.getenv("PLAUSIBLE_SITE_ID")`.
#' @param api_key Plausible API key. Defaults to
#'   `Sys.getenv("PLAUSIBLE_API_KEY")`.
#' @param base_url Plausible instance URL. Defaults to
#'   `Sys.getenv("PLAUSIBLE_URL", "https://plausible.io")`.
#' @param period Time period: `"30d"`, `"7d"`, `"month"`, `"6mo"`, `"12mo"`.
#' @return Named list with `aggregate`, `timeseries`, `top_pages`, and
#'   `top_sources`.
#' @export
website_collect_analytics <- function(
  site_id = Sys.getenv("PLAUSIBLE_SITE_ID"),
  api_key = Sys.getenv("PLAUSIBLE_API_KEY"),
  base_url = Sys.getenv("PLAUSIBLE_URL", "https://plausible.io"),
  period = c("30d", "7d", "month", "6mo", "12mo")
) {
  period <- match.arg(period)
  cli::cli_h2("Collecting website analytics for {site_id}")

  aggregate <- website_plausible_query(
    base_url,
    api_key,
    "/api/v1/stats/aggregate",
    site_id = site_id,
    period = period,
    metrics = "visitors,pageviews,bounce_rate,visit_duration"
  )

  timeseries <- website_plausible_query(
    base_url,
    api_key,
    "/api/v1/stats/timeseries",
    site_id = site_id,
    period = period,
    metrics = "visitors,pageviews"
  )

  top_pages <- website_plausible_query(
    base_url,
    api_key,
    "/api/v1/stats/breakdown",
    site_id = site_id,
    period = period,
    property = "event:page",
    metrics = "visitors,pageviews",
    limit = "10"
  )

  top_sources <- website_plausible_query(
    base_url,
    api_key,
    "/api/v1/stats/breakdown",
    site_id = site_id,
    period = period,
    property = "visit:source",
    metrics = "visitors",
    limit = "10"
  )

  cli::cli_alert_success(
    "Collected analytics: {aggregate$results$visitors$value} visitors"
  )

  list(
    site_id = site_id,
    period = period,
    aggregate = aggregate,
    timeseries = timeseries,
    top_pages = top_pages,
    top_sources = top_sources
  )
}

website_plausible_query <- function(base_url, api_key, endpoint, ...) {
  params <- list(...)
  req <- httr2::request(paste0(base_url, endpoint)) |>
    httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
    httr2::req_url_query(!!!params)

  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp)
}

#' Format website analytics as markdown
#'
#' @param analytics Data from [website_collect_analytics()].
#' @return Formatted markdown string.
#' @export
website_format_analytics <- function(analytics) {
  template_path <- system.file(
    "templates",
    "website-analytics.md",
    package = "jinx"
  )

  agg <- analytics$aggregate$results
  overview <- paste(
    "| Metric | Value |",
    "|--------|-------|",
    glue::glue("| Unique visitors | {agg$visitors$value} |"),
    glue::glue("| Total pageviews | {agg$pageviews$value} |"),
    glue::glue("| Bounce rate | {agg$bounce_rate$value}% |"),
    glue::glue(
      "| Avg. visit duration | {format_duration(agg$visit_duration$value)} |"
    ),
    sep = "\n"
  )

  ts <- analytics$timeseries$results
  ts_lines <- if (length(ts) > 0) {
    visitors <- vapply(ts, function(x) x$visitors, integer(1))
    sparkline <- paste(analytics_compute_sparkline(visitors), collapse = "")
    paste(
      glue::glue("Visitors trend: {sparkline}"),
      "",
      "| Date | Visitors | Pageviews |",
      "|------|----------|-----------|",
      paste(
        vapply(
          ts,
          function(x) {
            glue::glue("| {x$date} | {x$visitors} | {x$pageviews} |")
          },
          character(1)
        ),
        collapse = "\n"
      ),
      sep = "\n"
    )
  } else {
    "No timeseries data available."
  }

  pages <- analytics$top_pages$results
  pages_lines <- if (length(pages) > 0) {
    paste(
      "| Page | Visitors | Pageviews |",
      "|------|----------|-----------|",
      paste(
        vapply(
          pages,
          function(x) {
            glue::glue("| `{x$page}` | {x$visitors} | {x$pageviews} |")
          },
          character(1)
        ),
        collapse = "\n"
      ),
      sep = "\n"
    )
  } else {
    "No page data available."
  }

  sources <- analytics$top_sources$results
  sources_lines <- if (length(sources) > 0) {
    paste(
      "| Source | Visitors |",
      "|--------|----------|",
      paste(
        vapply(
          sources,
          function(x) {
            source_name <- x$source %||% "Direct / None"
            glue::glue("| {source_name} | {x$visitors} |")
          },
          character(1)
        ),
        collapse = "\n"
      ),
      sep = "\n"
    )
  } else {
    "No referral data available."
  }

  if (nzchar(template_path)) {
    render_template(
      template_path,
      list(
        SITE_ID = analytics$site_id,
        PERIOD = analytics$period,
        OVERVIEW = overview,
        TIMESERIES = ts_lines,
        TOP_PAGES = pages_lines,
        TOP_SOURCES = sources_lines,
        DATE = as.character(Sys.Date())
      )
    )
  } else {
    paste(
      glue::glue("## Website Analytics - {analytics$site_id}\n"),
      glue::glue("Period: {analytics$period}\n"),
      "### Overview\n",
      overview,
      "\n### Traffic Trend\n",
      ts_lines,
      "\n### Top Pages\n",
      pages_lines,
      "\n### Top Sources\n",
      sources_lines,
      glue::glue("\n_Generated by jinx on {Sys.Date()}_"),
      sep = "\n"
    )
  }
}

#' Generate a website analytics report
#'
#' Collects Plausible analytics and formats as markdown.
#'
#' @inheritParams website_collect_analytics
#' @param output_path Optional path to write JSON data.
#' @return Named list with `analytics` and `markdown` (invisibly).
#' @export
website_generate_report <- function(
  site_id = Sys.getenv("PLAUSIBLE_SITE_ID"),
  api_key = Sys.getenv("PLAUSIBLE_API_KEY"),
  base_url = Sys.getenv("PLAUSIBLE_URL", "https://plausible.io"),
  period = c("30d", "7d", "month", "6mo", "12mo"),
  output_path = NULL
) {
  period <- match.arg(period)
  analytics <- website_collect_analytics(
    site_id = site_id,
    api_key = api_key,
    base_url = base_url,
    period = period
  )
  markdown <- website_format_analytics(analytics)

  result <- list(analytics = analytics, markdown = markdown)

  if (!is.null(output_path)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(result, output_path, pretty = TRUE, auto_unbox = TRUE)
    cli::cli_alert_success("Website analytics written to {output_path}")
  }

  invisible(result)
}

#' Publish website analytics as a GitHub issue
#'
#' @param report_data Data from [website_generate_report()].
#' @param org GitHub organization.
#' @param target_repo Repository to publish to.
#' @param slack_channel Optional Slack channel to post a summary to.
#' @return Issue URL (invisibly).
#' @export
website_publish_report <- function(
  report_data,
  org = "rladies",
  target_repo = "global-team",
  slack_channel = NULL
) {
  body <- report_data$markdown %||% "No website analytics data available."
  site <- report_data$analytics$site_id %||% "website"

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = target_repo,
    title = cli::format_inline("Website Analytics ({site}) - {Sys.Date()}"),
    body = body,
    labels = list("report", "website-analytics")
  )

  cli::cli_alert_success("Website analytics published: {issue$html_url}")

  if (!is.null(slack_channel)) {
    slack_body <- website_format_slack(report_data, issue$html_url)
    slack_post_message(slack_body, channel = slack_channel)
  }

  invisible(issue$html_url)
}

website_format_slack <- function(report_data, issue_url) {
  agg <- report_data$analytics$aggregate$results
  site <- report_data$analytics$site_id
  period <- report_data$analytics$period

  ts <- report_data$analytics$timeseries$results
  sparkline <- if (length(ts) > 0) {
    visitors <- vapply(ts, function(x) x$visitors, integer(1))
    paste(analytics_compute_sparkline(visitors), collapse = "")
  } else {
    ""
  }

  lines <- c(
    glue::glue(
      ":globe_with_meridians: *Website Analytics ({site}) - {Sys.Date()}*"
    ),
    glue::glue("Period: {period}"),
    "",
    glue::glue(
      ":busts_in_silhouette: Visitors: *{agg$visitors$value}*",
      " | :page_facing_up: Pageviews: *{agg$pageviews$value}*"
    ),
    glue::glue(
      ":leftwards_arrow_with_hook: Bounce rate: {agg$bounce_rate$value}%",
      " | :clock1: Avg. duration:",
      " {format_duration(agg$visit_duration$value)}"
    )
  )

  if (nzchar(sparkline)) {
    lines <- c(lines, glue::glue("Traffic: {sparkline}"))
  }

  top_pages <- report_data$analytics$top_pages$results
  if (length(top_pages) >= 3) {
    lines <- c(lines, "", "*Top pages:*")
    for (i in seq_len(min(3, length(top_pages)))) {
      p <- top_pages[[i]]
      lines <- c(lines, glue::glue("  {i}. `{p$page}` ({p$visitors} visitors)"))
    }
  }

  lines <- c(lines, "", glue::glue("<{issue_url}|View full report>"))
  paste(lines, collapse = "\n")
}

format_duration <- function(seconds) {
  if (is.null(seconds) || is.na(seconds) || seconds == 0) {
    return("0s")
  }
  mins <- seconds %/% 60
  secs <- seconds %% 60
  if (mins > 0) {
    glue::glue("{mins}m {secs}s")
  } else {
    glue::glue("{secs}s")
  }
}
