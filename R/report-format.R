#' Format a report as markdown
#'
#' @param report Report data from [generate_report()].
#' @return Character string with markdown-formatted report.
#' @export
format_report_markdown <- function(report) {
  s <- report$summary
  header <- glue::glue(
    "## {report$type} Activity Report\n",
    "**Period**: {report$period$from} to {report$period$to}\n",
    "**Generated**: {format(report$generated_at, '%Y-%m-%d %H:%M UTC')}\n"
  )

  overview <- glue::glue(
    "### Overview\n",
    "| Metric | Count |\n",
    "|--------|-------|\n",
    "| Active repositories | {s$active_repos} |\n",
    "| Total commits | {s$total_commits} |\n",
    "| PRs opened | {s$total_prs} |\n",
    "| PRs merged | {s$total_prs_merged} |\n",
    "| Issues opened | {s$total_issues} |\n",
    "| Issues closed | {s$total_issues_closed} |\n"
  )

  active <- Filter(
    function(r) {
      r$commits > 0 || r$prs_opened > 0 || r$issues_opened > 0
    },
    report$repos
  )

  if (length(active) == 0) {
    details <- "### Repository Details\nNo activity in this period.\n"
  } else {
    active <- active[order(-vapply(active, function(r) r$commits, integer(1)))]
    rows <- vapply(
      active,
      function(r) {
        glue::glue(
          "| {r$repo} | {r$commits}",
          " | {r$prs_opened} | {r$prs_merged}",
          " | {r$issues_opened} | {r$issues_closed} |"
        )
      },
      character(1)
    )

    details <- paste0(
      "### Repository Details\n",
      "| Repository | Commits | PRs Opened | PRs Merged",
      " | Issues Opened | Issues Closed |\n",
      "|------------|---------|------------|------------",
      "|---------------|---------------|\n",
      paste(rows, collapse = "\n"),
      "\n"
    )
  }

  paste(header, overview, details, sep = "\n")
}
