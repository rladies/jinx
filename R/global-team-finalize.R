#' Finalize global team onboarding for an accepted member
#'
#' Adds the user to their specific team and creates a tracking issue
#' with the onboarding checklist.
#'
#' @param username GitHub username.
#' @param team Team slug (e.g. "website").
#' @param name Full name.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @return The created issue URL (invisibly).
#' @export
gt_finalize_onboarding <- function(
  username,
  team,
  name = username,
  org = "rladies"
) {
  config <- load_teams_config()
  team_def <- team_get_by_slug(team, config)

  if (is.null(team_def)) {
    cli::cli_abort("Unknown team {.val {team}}")
  }

  gh::gh(
    "PUT /orgs/{org}/teams/{team_slug}/memberships/{username}",
    org = org,
    team_slug = team,
    username = username,
    role = team_def$role %||% "member"
  )
  cli::cli_alert_success("Added {.val {username}} to {.val {team}} team")

  if (length(team_def$repos) > 0) {
    cli::cli_alert_info(
      "{.val {username}} inherits access to {.val {team}} team repos: \\
      {.val {team_def$repos}}"
    )
  }

  body <- gt_build_onboarding_body(team, username, name)
  title <- cli::format_inline("Onboarding {name} to {team_def$name} team")

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = "global-team",
    title = title,
    body = body,
    labels = list("onboarding", team)
  )

  notify_teams <- config$default_assignees
  if (!is.null(team_def$notify_teams)) {
    notify_teams <- unique(c(notify_teams, team_def$notify_teams))
  }
  review_notify_teams(org, "global-team", issue$number, notify_teams)

  tryCatch(
    gt_schedule_onboarding_meeting(
      issue_number = issue$number,
      name = name,
      team_name = team_def$name,
      org = org
    ),
    error = function(cnd) {
      cli::cli_alert_warning(
        "Could not open onboarding meeting poll: {conditionMessage(cnd)}"
      )
    }
  )

  cli::cli_alert_success("Created onboarding issue: {issue$html_url}")
  invisible(issue$html_url)
}

#' Notify teams by commenting on an issue with @-mentions
#' @param org GitHub organization.
#' @param repo Repository name.
#' @param issue_number Issue number.
#' @param teams Character vector of team slugs to mention.
#' @keywords internal
#' @noRd
review_notify_teams <- function(org, repo, issue_number, teams) {
  if (length(teams) == 0) {
    return(invisible())
  }

  mentions <- paste(
    vapply(teams, function(t) cli::format_inline("@{org}/{t}"), character(1)),
    collapse = " "
  )

  gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = repo,
    issue_number = issue_number,
    body = cli::format_inline("cc {mentions}")
  )

  cli::cli_alert_info("Notified teams: {paste(teams, collapse = ', ')}")
  invisible()
}
