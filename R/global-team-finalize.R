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
gt_finalize_onboarding <- function(username, team, name = username,
                                            org = "rladies") {
  config <- load_teams_config()
  team_def <- team_by_slug(team, config)

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

  for (repo_name in team_def$repos) {
    cli::cli_alert_info("Granted access to {.val {org}/{repo_name}}")
  }

  body <- gt_build_onboarding_body(team, username, name)
  title <- glue::glue("Onboarding {name} to {team_def$name} team")

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = "global-team",
    title = title,
    body = body,
    labels = list("onboarding", team)
  )

  assignees <- config$default_assignees
  if (!is.null(team_def$notify_teams)) {
    assignees <- unique(c(assignees, team_def$notify_teams))
  }

  cli::cli_alert_success("Created onboarding issue: {issue$html_url}")
  invisible(issue$html_url)
}
