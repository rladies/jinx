#' Post a reply comment on an issue or PR
#'
#' Posts as the authenticated user (jinx\[bot\] when using a GitHub App token).
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param issue_number Issue or PR number.
#' @param body Comment body (markdown).
#' @return The API response (invisibly).
#' @export
post_reply <- function(owner, repo, issue_number, body) {
  response <- gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = owner,
    repo = repo,
    issue_number = issue_number,
    body = body
  )
  cli::cli_alert_success("Posted reply on {owner}/{repo}#{issue_number}")
  invisible(response)
}
