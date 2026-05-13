#' Check pending global team invitations
#'
#' Lists pending invitations and triggers finalization for accepted ones.
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @return Character vector of usernames that have accepted their invitation
#'   (invisibly).
#' @export
global_team_check_invitations <- function(org = "rladies") {
  pending <- gh::gh(
    "GET /orgs/{org}/invitations",
    org = org,
    .limit = Inf
  )

  if (length(pending) == 0) {
    cli::cli_alert_info("No pending invitations")
    return(invisible(character()))
  }

  accepted <- character()
  for (invite in pending) {
    username <- invite$login
    status <- tryCatch(
      {
        gh::gh(
          "GET /orgs/{org}/members/{username}",
          org = org,
          username = username
        )
        "member"
      },
      http_error_404 = function(e) "pending"
    )

    if (status == "member") {
      cli::cli_alert_success("{.val {username}} accepted invitation")
      accepted <- c(accepted, username)
    } else {
      cli::cli_alert_info("{.val {username}} invitation still pending")
    }
  }

  invisible(accepted)
}

#' @rdname global_team_check_invitations
#' @export
gt_check_invitations <- function(org = "rladies") {
  global_team_check_invitations(org = org)
}
