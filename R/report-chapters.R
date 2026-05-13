#' Generate a chapter health report
#'
#' Analyzes chapter activity data and publishes a summary report.
#'
#' @param months Inactivity threshold in months. Defaults to 6.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param target_repo Repository to publish report to.
#'   Defaults to `"global-team"`.
#' @return Issue URL (invisibly).
#' @export
chapter_report_health <- function(
  months = 6,
  org = "rladies",
  target_repo = "global-team"
) {
  health <- chapter_check_health(months = months, org = org)

  if (nrow(health) == 0) {
    cli::cli_alert_warning("No chapter data available for report")
    return(invisible(NULL))
  }

  body <- format_chapter_report(health, months)

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = target_repo,
    title = glue::glue("Chapter health report - {Sys.Date()}"),
    body = body,
    labels = list("report", "chapters")
  )

  cli::cli_alert_success("Chapter health report published: {issue$html_url}")
  invisible(issue$html_url)
}

format_chapter_report <- function(health, months) {
  n_active <- sum(health$status == "active")
  n_inactive <- sum(health$status == "inactive")

  header <- glue::glue(
    "## Chapter Health Report\n",
    "**Generated**: {Sys.Date()}\n",
    "**Threshold**: {months} months without events\n\n",
    "### Summary\n",
    "- **Active chapters**: {n_active}\n",
    "- **Inactive chapters**: {n_inactive}\n",
    "- **Total**: {nrow(health)}\n"
  )

  inactive <- health[health$status == "inactive", ]
  if (nrow(inactive) == 0) {
    details <- "\n### Inactive Chapters\nAll chapters are active!\n"
  } else {
    inactive <- inactive[order(-inactive$months_inactive), ]
    rows <- vapply(
      seq_len(nrow(inactive)),
      function(i) {
        r <- inactive[i, ]
        glue::glue("| {r$chapter} | {r$last_event} | {r$months_inactive} |")
      },
      character(1)
    )

    details <- paste0(
      "\n### Inactive Chapters\n",
      "| Chapter | Last Event | Months Inactive |\n",
      "|---------|------------|-----------------|\n",
      paste(rows, collapse = "\n"),
      "\n"
    )
  }

  paste(header, details, sep = "\n")
}
