#' Generate an organization activity report
#'
#' Collects stats across org repos: commits, PRs, issues.
#'
#' @param type Report type: `"weekly"` or `"monthly"`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param exclude_pattern Regex to exclude repos. Defaults to `"^meetup-"`.
#' @return A named list with report data (invisibly).
#' @export
generate_report <- function(
  type = c("weekly", "monthly"),
  org = "rladies",
  exclude_pattern = "^meetup-"
) {
  type <- match.arg(type)
  days <- if (type == "weekly") 7 else 30
  since <- format(Sys.Date() - days, "%Y-%m-%dT00:00:00Z")

  cli::cli_h2("Generating {type} report for {org}")

  repos <- gh::gh(
    "GET /orgs/{org}/repos",
    org = org,
    type = "all",
    sort = "updated",
    .limit = Inf
  )

  repos <- Filter(function(r) !grepl(exclude_pattern, r$name), repos)
  cli::cli_alert_info("Scanning {length(repos)} repositories")

  repo_stats <- lapply(repos, function(r) {
    tryCatch(
      collect_repo_stats(org, r$name, since),
      error = function(e) {
        list(
          repo = r$name,
          commits = 0,
          prs_opened = 0,
          prs_merged = 0,
          issues_opened = 0,
          issues_closed = 0
        )
      }
    )
  })

  report <- list(
    type = type,
    org = org,
    period = list(
      from = as.character(Sys.Date() - days),
      to = as.character(Sys.Date())
    ),
    generated_at = Sys.time(),
    repos = repo_stats,
    summary = summarize_stats(repo_stats)
  )

  cli::cli_alert_success(
    "Report generated: {report$summary$total_commits} commits, {report$summary$total_prs} PRs, {report$summary$total_issues} issues"
  )
  invisible(report)
}

collect_repo_stats <- function(org, repo, since) {
  commits <- tryCatch(
    gh::gh(
      "GET /repos/{org}/{repo}/commits",
      org = org,
      repo = repo,
      since = since,
      .limit = Inf
    ),
    error = function(e) list()
  )

  prs <- tryCatch(
    gh::gh(
      "GET /repos/{org}/{repo}/pulls",
      org = org,
      repo = repo,
      state = "all",
      sort = "created",
      direction = "desc",
      .limit = 50
    ),
    error = function(e) list()
  )

  prs_in_period <- Filter(function(p) p$created_at >= since, prs)
  prs_merged <- Filter(
    function(p) !is.null(p$merged_at) && p$merged_at >= since,
    prs
  )

  issues <- tryCatch(
    gh::gh(
      "GET /repos/{org}/{repo}/issues",
      org = org,
      repo = repo,
      state = "all",
      since = since,
      sort = "created",
      direction = "desc",
      .limit = 50
    ),
    error = function(e) list()
  )

  issues_only <- Filter(function(i) is.null(i$pull_request), issues)
  issues_opened <- Filter(function(i) i$created_at >= since, issues_only)
  issues_closed <- Filter(
    function(i) {
      !is.null(i$closed_at) && i$closed_at >= since
    },
    issues_only
  )

  list(
    repo = repo,
    commits = length(commits),
    prs_opened = length(prs_in_period),
    prs_merged = length(prs_merged),
    issues_opened = length(issues_opened),
    issues_closed = length(issues_closed)
  )
}

summarize_stats <- function(repo_stats) {
  list(
    total_commits = sum(vapply(repo_stats, function(r) r$commits, integer(1))),
    total_prs = sum(vapply(repo_stats, function(r) r$prs_opened, integer(1))),
    total_prs_merged = sum(vapply(
      repo_stats,
      function(r) r$prs_merged,
      integer(1)
    )),
    total_issues = sum(vapply(
      repo_stats,
      function(r) r$issues_opened,
      integer(1)
    )),
    total_issues_closed = sum(vapply(
      repo_stats,
      function(r) r$issues_closed,
      integer(1)
    )),
    active_repos = sum(vapply(
      repo_stats,
      function(r) {
        r$commits > 0 || r$prs_opened > 0 || r$issues_opened > 0
      },
      logical(1)
    ))
  )
}

#' Publish a report as a GitHub issue
#'
#' @param report Report data from [generate_report()].
#' @param target_repo Repository to publish to. Defaults to `"global-team"`.
#' @param org Organization. Defaults to `"rladies"`.
#' @return Issue URL (invisibly).
#' @export
publish_report <- function(
  report,
  target_repo = "global-team",
  org = "rladies"
) {
  body <- format_report_markdown(report)
  title <- glue::glue("{report$type} activity report - {report$period$to}")

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = target_repo,
    title = title,
    body = body,
    labels = list("report", report$type)
  )

  cli::cli_alert_success("Published report: {issue$html_url}")
  invisible(issue$html_url)
}
