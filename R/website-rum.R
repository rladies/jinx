#' Collect Cloudflare RUM (Web Analytics) traffic data
#'
#' Queries the Cloudflare Web Analytics beacon data for a date range,
#' via [cloudflarer::cf_rum_page_views()] and [cloudflarer::cf_rum_top()].
#' A sibling to [website_collect_analytics()] (which queries Plausible) —
#' Cloudflare RUM is a separate, beacon-based data source.
#'
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param site_tag RUM site tag, as returned by
#'   `cloudflarer::cf_list_rum_sites()`. Defaults to env
#'   `CLOUDFLARE_RUM_SITE_TAG`.
#' @param token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param since,until Date range, half-open `[since, until)`. Defaults to
#'   the last 30 days.
#' @return Named list with `site_tag`, `since`, `until`, `pageviews`,
#'   `top_pages`, `top_sources`, and `top_countries`.
#' @export
rum_collect_analytics <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  site_tag = Sys.getenv("CLOUDFLARE_RUM_SITE_TAG"),
  token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  since = Sys.Date() - 30,
  until = Sys.Date()
) {
  cli::cli_h2("Collecting Cloudflare RUM analytics for {site_tag}")

  pageviews <- cloudflarer::cf_rum_page_views(
    account_id = account_id,
    site_tag = site_tag,
    since = since,
    until = until,
    token = token
  )
  top_pages <- cloudflarer::cf_rum_top(
    account_id = account_id,
    site_tag = site_tag,
    since = since,
    until = until,
    dimension = "requestPath",
    token = token
  )
  top_sources <- cloudflarer::cf_rum_top(
    account_id = account_id,
    site_tag = site_tag,
    since = since,
    until = until,
    dimension = "refererHost",
    token = token
  )
  top_countries <- cloudflarer::cf_rum_top(
    account_id = account_id,
    site_tag = site_tag,
    since = since,
    until = until,
    dimension = "countryName",
    token = token
  )

  cli::cli_alert_success(
    "Collected RUM analytics: {sum(pageviews$pageviews)} pageviews"
  )

  list(
    site_tag = site_tag,
    since = since,
    until = until,
    pageviews = pageviews,
    top_pages = top_pages,
    top_sources = top_sources,
    top_countries = top_countries
  )
}

rum_format_top_table <- function(df, dim_label, empty_message) {
  if (nrow(df) == 0) {
    return(empty_message)
  }
  names(df)[1] <- "dim"
  paste(
    glue::glue("| {dim_label} | Count |"),
    "|------|-------|",
    paste(glue::glue_data(df, "| {dim} | {count} |"), collapse = "\n"),
    sep = "\n"
  )
}

#' Format Cloudflare RUM analytics as markdown
#'
#' @param analytics Data from [rum_collect_analytics()].
#' @return Character string with markdown-formatted report.
#' @export
rum_format_analytics <- function(analytics) {
  total_pageviews <- sum(analytics$pageviews$pageviews)

  overview <- paste(
    "| Metric | Value |",
    "|--------|-------|",
    glue::glue("| Total pageviews | {total_pageviews} |"),
    sep = "\n"
  )

  ts_lines <- if (nrow(analytics$pageviews) > 0) {
    sparkline <- paste(
      analytics_compute_sparkline(analytics$pageviews$pageviews),
      collapse = ""
    )
    paste(
      glue::glue("Pageviews trend: {sparkline}"),
      "",
      "| Date | Pageviews |",
      "|------|-----------|",
      paste(
        glue::glue_data(analytics$pageviews, "| {date} | {pageviews} |"),
        collapse = "\n"
      ),
      sep = "\n"
    )
  } else {
    "No timeseries data available."
  }

  pages_lines <- rum_format_top_table(
    analytics$top_pages,
    "Path",
    "No page data available."
  )
  sources_lines <- rum_format_top_table(
    analytics$top_sources,
    "Referrer",
    "No referral data available."
  )
  countries_lines <- rum_format_top_table(
    analytics$top_countries,
    "Country",
    "No country data available."
  )

  glue::glue(
    "## Cloudflare Web Analytics - {analytics$site_tag}\n",
    "Period: {analytics$since} to {analytics$until}\n",
    "### Overview\n",
    "{overview}\n",
    "### Traffic Trend\n",
    "{ts_lines}\n",
    "### Top Pages\n",
    "{pages_lines}\n",
    "### Top Referrers\n",
    "{sources_lines}\n",
    "### Top Countries\n",
    "{countries_lines}\n"
  )
}

#' Generate a Cloudflare RUM analytics report
#'
#' Collects Cloudflare Web Analytics data and formats it as markdown. A
#' sibling to [website_generate_report()] (Plausible-backed).
#'
#' @inheritParams rum_collect_analytics
#' @param output_path Optional path to write JSON data.
#' @return Named list with `analytics` and `markdown` (invisibly).
#' @export
rum_generate_report <- function(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  site_tag = Sys.getenv("CLOUDFLARE_RUM_SITE_TAG"),
  token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  since = Sys.Date() - 30,
  until = Sys.Date(),
  output_path = NULL
) {
  analytics <- rum_collect_analytics(
    account_id = account_id,
    site_tag = site_tag,
    token = token,
    since = since,
    until = until
  )
  markdown <- rum_format_analytics(analytics)

  result <- list(analytics = analytics, markdown = markdown)

  if (!is.null(output_path)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(result, output_path, pretty = TRUE, auto_unbox = TRUE)
    cli::cli_alert_success("RUM analytics written to {output_path}")
  }

  invisible(result)
}
