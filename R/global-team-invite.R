#' Invite a user to the R-Ladies global team
#'
#' Sends an organization membership invitation and adds the user to the
#' global team.
#'
#' @param username GitHub username (without `@`).
#' @param team Team slug (e.g. "website").
#' @param name Full name (used in issue templates).
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @return Invisibly returns `NULL`. Called for its side effect of sending
#'   the invitation and adding the user to the specified team.
#' @export
gt_invite <- function(username, team, name = username, org = "rladies") {
  config <- load_teams_config()

  if (!team %in% team_slugs(config)) {
    cli::cli_abort(
      "Unknown team {.val {team}}. Valid: {.val {team_slugs(config)}}"
    )
  }

  gh::gh(
    "PUT /orgs/{org}/memberships/{username}",
    org = org,
    username = username,
    role = "member"
  )
  cli::cli_alert_success("Invited {.val {username}} to {.val {org}}")

  gh::gh(
    "PUT /orgs/{org}/teams/{team_slug}/memberships/{username}",
    org = org,
    team_slug = "global",
    username = username,
    role = "member"
  )
  cli::cli_alert_success("Added {.val {username}} to global team")

  invisible()
}
