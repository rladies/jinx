#' Generate a chapter health report
#'
#' Analyzes chapter activity data and returns a formatted markdown
#' summary.
#'
#' @param months Inactivity threshold in months. Defaults to 6.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @return Markdown report body (invisibly), or `NULL` if no data.
#' @export
chapter_report_health <- function(months = 6, org = "rladies") {
  health <- chapter_check_health(months = months, org = org)

  if (nrow(health) == 0) {
    cli::cli_alert_warning("No chapter data available for report")
    return(invisible(NULL))
  }

  body <- chapter_format_report(health, months)
  cli::cli_alert_success("Chapter health report generated")
  invisible(body)
}

chapter_format_report <- function(health, months) {
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
