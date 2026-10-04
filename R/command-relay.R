#' Allowed author associations for a relayed command
#'
#' The same set the command workflows gate on: someone who is not at
#' least a repository member cannot reach jinx by commenting.
#'
#' @return Character vector of author associations.
#' @keywords internal
#' @noRd
cmd_relay_associations <- function() {
  c("OWNER", "MEMBER", "COLLABORATOR")
}

#' How long a relayed comment stays actionable, in seconds
#'
#' A relay carries only a comment id, so the dispatch is replayable by
#' anyone who can dispatch to this repository. Bounding the age means a
#' replay can only re-run a command an authorised member wrote moments
#' ago, which the commands are already idempotent against.
#'
#' @return Number of seconds.
#' @keywords internal
#' @noRd
cmd_relay_max_age <- function() 600

#' Split an `owner/repo` string
#' @keywords internal
#' @noRd
cmd_relay_split_repo <- function(repo) {
  parts <- strsplit(repo %or% "", "/", fixed = TRUE)[[1]]
  if (length(parts) != 2 || !all(nzchar(parts))) {
    cli::cli_abort("{.val {repo}} is not an {.code owner/repo} reference.")
  }
  parts
}

#' Read a relayed command from its originating comment
#'
#' A repository that wants `/jinx` commands relays only the comment's
#' location, never the command text or who wrote it. Both are read back
#' from the API here, with jinx's own credentials, so a forged dispatch
#' cannot put words in an authorised member's mouth: the worst it can do
#' is re-run a command that member genuinely just posted.
#'
#' @param repo Originating repository as `"owner/repo"`.
#' @param comment_id Issue comment id.
#' @param max_age Seconds a comment stays actionable.
#' @param now Current time, for testing.
#' @return A list with `text`, `actor`, `repo`, `owner`, `name`, and
#'   `issue`.
#' @export
cmd_relay_resolve <- function(
  repo,
  comment_id,
  max_age = cmd_relay_max_age(),
  now = Sys.time()
) {
  parts <- cmd_relay_split_repo(repo)

  comment <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/comments/{comment_id}",
    owner = parts[1],
    repo = parts[2],
    comment_id = comment_id
  )

  text <- trimws(comment$body %or% "")
  if (!startsWith(text, "/jinx ")) {
    cli::cli_abort("Comment {comment_id} in {.val {repo}} is not a command.")
  }

  association <- comment$author_association %or% ""
  if (!association %in% cmd_relay_associations()) {
    cli::cli_abort(c(
      "Comment {comment_id} in {.val {repo}} is not from a member.",
      "i" = "Author association was {.val {association}}."
    ))
  }

  age <- as.numeric(difftime(
    now,
    as.POSIXct(comment$created_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    units = "secs"
  ))
  if (is.na(age) || age > max_age) {
    cli::cli_abort(c(
      "Comment {comment_id} in {.val {repo}} is too old to relay.",
      "i" = "Commands are relayed within {max_age} seconds of posting."
    ))
  }

  issue <- sub("^.*/", "", comment$issue_url %or% "")
  if (!grepl("^[0-9]+$", issue)) {
    cli::cli_abort("Could not read an issue number for comment {comment_id}.")
  }

  list(
    text = text,
    actor = comment$user$login %or% "",
    repo = repo,
    owner = parts[1],
    name = parts[2],
    issue = as.integer(issue)
  )
}
