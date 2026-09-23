#' The comment text that approves a chapter mailbox
#' @keywords internal
#' @noRd
chapter_email_marker <- function() "/jinx approve-email"

#' Teams whose members may approve a chapter mailbox
#' @keywords internal
#' @noRd
chapter_email_approver_teams <- function() c("chapter-onboarding", "global")

#' Confirm an approver's team membership, failing closed
#'
#' [is_team_member()] treats an unreachable API as membership, which is
#' the right call for posting a welcome message and the wrong one for
#' creating an account in the domain. This check says no whenever it
#' cannot prove yes.
#'
#' @param login GitHub login of the approver.
#' @param org GitHub organization.
#' @param teams Team slugs to accept.
#' @return `TRUE` only when membership is confirmed.
#' @keywords internal
#' @noRd
chapter_email_approver_is_member <- function(
  login,
  org,
  teams = chapter_email_approver_teams()
) {
  for (team in teams) {
    confirmed <- tryCatch(
      {
        membership <- gh::gh(
          "GET /orgs/{org}/teams/{team}/memberships/{username}",
          org = org,
          team = team,
          username = login
        )
        identical(membership$state, "active")
      },
      error = function(e) FALSE
    )
    if (isTRUE(confirmed)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Find the approvals on a chapter onboarding issue
#'
#' An approval is a comment containing the approval marker, written by a
#' confirmed member of an approving team. Bot comments never count, so
#' jinx cannot approve its own work.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return Character vector of approver logins, possibly empty.
#' @export
chapter_email_approvals <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  comments <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number,
    .limit = Inf
  )

  logins <- vapply(
    comments,
    function(comment) chapter_email_approval_login(comment),
    character(1)
  )
  logins <- unique(logins[nzchar(logins)])

  authorized <- vapply(
    logins,
    chapter_email_approver_is_member,
    logical(1),
    org = org,
    USE.NAMES = FALSE
  )
  for (login in logins[!authorized]) {
    cli::cli_alert_warning(
      "Ignoring approval from @{login}: not a confirmed team member"
    )
  }
  logins[authorized]
}

#' The approver login on one comment, or "" when it is not an approval
#' @keywords internal
#' @noRd
chapter_email_approval_login <- function(comment) {
  body <- comment$body %or% ""
  login <- comment$user$login %or% ""
  if (!grepl(chapter_email_marker(), body, fixed = TRUE)) {
    return("")
  }
  if (!nzchar(login) || is_bot(login)) {
    return("")
  }
  login
}

#' Provision a chapter mailbox once a human has approved it
#'
#' Reads the chapter from the onboarding issue's own machine-readable
#' block, checks that a member of an approving team has left an
#' approval comment, and only then asks the worker to create the
#' mailbox. The address is posted back on the issue and the email step
#' of the checklist is ticked.
#'
#' The approval is a separate, deliberate act on the specific issue:
#' being allowed to run the command is not on its own enough to create
#' an account, so a stray dispatch or a mistaken command cannot
#' provision anything.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The created address (invisibly).
#' @export
chapter_email_provision <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  meta <- chapter_meta_fetch(issue_number, org, onboarding_repo)
  city <- meta$city %or% NULL
  if (is.null(city)) {
    cli::cli_abort(c(
      "Issue #{issue_number} does not say which chapter this is.",
      "i" = "It carries no jinx block, so there is no city to provision."
    ))
  }

  approvers <- chapter_email_approvals(issue_number, org, onboarding_repo)
  if (length(approvers) == 0) {
    cli::cli_abort(c(
      "No approval on issue #{issue_number}, so nothing was created.",
      "i" = paste0(
        "A member of @",
        org,
        "/chapter-onboarding must comment ",
        "`",
        chapter_email_marker(),
        "` on the issue first."
      )
    ))
  }

  email <- chapter_mailbox_create(city)

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    chapter_email_comment(email, approvers)
  )

  chapter_checklist_tick(
    issue_number,
    "create the chapter email",
    org = org,
    onboarding_repo = onboarding_repo
  )

  invisible(email)
}

#' The comment announcing a created mailbox
#' @keywords internal
#' @noRd
chapter_email_comment <- function(email, approvers) {
  who <- paste0("@", approvers, collapse = ", ")
  glue::glue(
    "Created the chapter mailbox **{email}**, approved by {who}.\n\n",
    "The password was generated inside the worker and deliberately not ",
    "recorded anywhere - issue the handover from the Admin console, ",
    "where the account is already set to require a password change at ",
    "first sign-in.\n\n",
    "Add this address to the chapter's website entry once the organisers ",
    "have signed in."
  )
}
