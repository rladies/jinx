#' Send reminders on stale global team onboarding/offboarding issues
#'
#' Finds open issues with onboarding or offboarding labels that haven't
#' been updated in `days` days, and posts a reminder comment.
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param days Number of days without activity before reminding. Defaults to 30.
#' @param repo Repository to check. Defaults to `"global-team"`.
#' @return Invisibly returns `NULL`. Called for its side effect of posting
#'   reminder comments on stale issues.
#' @export
global_team_remind_stale <- function(org = "rladies", days = 30, repo = "global-team") {
  cutoff <- format(Sys.Date() - days, "%Y-%m-%d")
  stale <- list()

  for (label in c("onboarding", "offboarding")) {
    issues <- gh::gh(
      "GET /repos/{owner}/{repo}/issues",
      owner = org,
      repo = repo,
      labels = label,
      state = "open",
      sort = "updated",
      direction = "asc",
      .limit = Inf
    )

    for (issue in issues) {
      updated <- as.Date(sub("T.*", "", issue$updated_at))
      if (updated <= as.Date(cutoff)) {
        days_stale <- as.integer(Sys.Date() - updated)
        post_reply(
          org,
          repo,
          issue$number,
          glue::glue(
            "This issue has had no activity for over {days} days. ",
            "Please check if this {label} process can be completed or ",
            "if it needs attention."
          )
        )
        stale[[length(stale) + 1]] <- list(
          title = issue$title,
          url = issue$html_url,
          days = days_stale
        )
        cli::cli_alert_warning("Reminded: {issue$title} (#{issue$number})")
      }
    }
  }

  invisible(stale)
}

#' @rdname global_team_remind_stale
#' @export
gt_remind_stale <- function(org = "rladies", days = 30, repo = "global-team") {
  global_team_remind_stale(org = org, days = days, repo = repo)
}
