#' Create a global team offboarding issue
#'
#' @param username GitHub username.
#' @param team Team slug.
#' @param name Full name. Defaults to the username.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @return The created issue URL (invisibly).
#' @export
gt_create_offboarding <- function(
  username,
  team,
  name = username,
  org = "rladies"
) {
  config <- load_teams_config()
  team_def <- team_by_slug(team, config)

  if (is.null(team_def)) {
    cli::cli_abort("Unknown team {.val {team}}")
  }

  body <- gt_build_offboarding_body(team, username, name)
  title <- glue::glue("Offboarding {name} from {team_def$name} team")

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = "global-team",
    title = title,
    body = body,
    labels = list("offboarding", team)
  )

  cli::cli_alert_success("Created offboarding issue: {issue$html_url}")
  invisible(issue$html_url)
}

#' Finalize global team offboarding by removing user from teams
#'
#' @param username GitHub username.
#' @param team Team slug.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @export
gt_finalize_offboarding <- function(username, team, org = "rladies") {
  teams_to_remove <- c("global", team)

  for (team_slug in teams_to_remove) {
    tryCatch(
      {
        gh::gh(
          "DELETE /orgs/{org}/teams/{team_slug}/memberships/{username}",
          org = org,
          team_slug = team_slug,
          username = username
        )
        cli::cli_alert_success(
          "Removed {.val {username}} from {.val {team_slug}}"
        )
      },
      http_error_404 = function(e) {
        cli::cli_alert_info("{.val {username}} was not in {.val {team_slug}}")
      }
    )
  }

  invisible()
}
