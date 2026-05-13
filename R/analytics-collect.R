#' Collect chapter activity data
#'
#' Queries the GitHub API for repository activity metrics across all
#' non-meetup repos in the organization.
#'
#' @param org GitHub organization.
#' @param months Number of months of history.
#' @param exclude_pattern Regex pattern to exclude repos.
#' @return Data frame with columns: chapter, month, commits, prs, issues.
#' @export
analytics_collect_chapter_activity <- function(
  org = "rladies",
  months = 12,
  exclude_pattern = "^meetup-"
) {
  cli::cli_h2("Collecting chapter activity for {org}")

  repos <- gh::gh(
    "GET /orgs/{org}/repos",
    org = org,
    type = "all",
    .limit = Inf
  )
  repos <- Filter(function(r) !grepl(exclude_pattern, r$name), repos)
  cli::cli_alert_info("Scanning {length(repos)} repositories")

  since <- format(Sys.Date() - lubridate::dmonths(months), "%Y-%m-%dT00:00:00Z")
  all_data <- list()

  for (r in repos) {
    tryCatch(
      {
        stats <- analytics_collect_monthly_stats(org, r$name, since)
        if (!is.null(stats) && nrow(stats) > 0) {
          all_data[[length(all_data) + 1]] <- stats
        }
      },
      error = function(e) {
        cli::cli_alert_warning(
          "Failed to collect stats for {r$name}: {e$message}"
        )
      }
    )
  }

  if (length(all_data) == 0) {
    return(data.frame(
      chapter = character(0),
      month = character(0),
      commits = integer(0),
      prs = integer(0),
      issues = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  combined <- do.call(rbind, all_data)
  cli::cli_alert_success(
    "Collected activity for {length(all_data)} repositories"
  )
  combined
}

#' Collect contributor growth data
#'
#' @param org GitHub organization.
#' @param months Number of months of history.
#' @return Data frame with columns: month, new_contributors,
#'   total_contributors, active_repos.
#' @export
analytics_collect_contributor_growth <- function(org = "rladies", months = 12) {
  cli::cli_h2("Collecting contributor growth for {org}")

  events <- gh::gh(
    "GET /orgs/{org}/events",
    org = org,
    .limit = 300
  )

  contributors_by_month <- list()
  for (event in events) {
    if (is.null(event$actor$login)) {
      next
    }
    month <- substr(event$created_at, 1, 7)
    if (is.null(contributors_by_month[[month]])) {
      contributors_by_month[[month]] <- character(0)
    }
    contributors_by_month[[month]] <- unique(c(
      contributors_by_month[[month]],
      event$actor$login
    ))
  }

  if (length(contributors_by_month) == 0) {
    return(data.frame(
      month = character(0),
      new_contributors = integer(0),
      total_contributors = integer(0),
      active_repos = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  months_sorted <- sort(names(contributors_by_month))
  all_seen <- character(0)
  rows <- list()

  for (m in months_sorted) {
    current <- contributors_by_month[[m]]
    new_count <- sum(!current %in% all_seen)
    all_seen <- unique(c(all_seen, current))
    rows[[length(rows) + 1]] <- data.frame(
      month = m,
      new_contributors = new_count,
      total_contributors = length(all_seen),
      active_repos = 0L,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, rows)
}

analytics_collect_monthly_stats <- function(org, repo, since) {
  commits <- tryCatch(
    {
      gh::gh(
        "GET /repos/{owner}/{repo}/commits",
        owner = org,
        repo = repo,
        since = since,
        .limit = Inf
      )
    },
    error = function(e) list()
  )

  if (length(commits) == 0) {
    return(NULL)
  }

  months <- vapply(
    commits,
    function(c) {
      substr(c$commit$committer$date %||% "", 1, 7)
    },
    character(1)
  )

  counts <- as.data.frame(table(months), stringsAsFactors = FALSE)
  names(counts) <- c("month", "commits")
  counts$chapter <- repo
  counts$prs <- 0L
  counts$issues <- 0L
  counts$commits <- as.integer(counts$commits)

  counts[, c("chapter", "month", "commits", "prs", "issues")]
}
