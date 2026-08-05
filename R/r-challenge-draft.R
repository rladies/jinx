#' Open a proposed challenge issue in the review repo
#'
#' Creates a `status: proposed` issue in the challenge repo (default
#' `rladies/cauldron`) from a verified draft, labelled with its source and its
#' themed difficulty, ready for an organiser to review. Requires a
#' `GITHUB_PAT`/`GITHUB_TOKEN` with `issues: write` on the target repo.
#'
#' @param build Result of [r_challenge_draft_build()].
#' @param repo Target review repo as `"owner/name"`.
#' @param source Where the challenge came from, e.g. `"ai"`.
#' @return The created issue's URL, invisibly.
#' @export
r_challenge_open_issue <- function(
  build,
  repo = "rladies/cauldron",
  source = "ai"
) {
  challenge <- build$challenge
  parts <- strsplit(repo, "/", fixed = TRUE)[[1]]
  labels <- list(
    "status: proposed",
    paste0("source: ", source),
    paste0("difficulty: ", r_challenge_difficulty_label(challenge$difficulty))
  )
  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = parts[1],
    repo = parts[2],
    title = r_challenge_issue_title(challenge),
    body = r_challenge_format_issue(build, source = source),
    labels = labels
  )
  cli::cli_alert_success("Proposed challenge: {issue$html_url}")
  invisible(issue$html_url)
}

#' Draft, verify, and propose a weekly R challenge
#'
#' Top-level entry for the draft cron: builds a fully verified challenge with
#' [r_challenge_draft_build()] and, if one passes every gate, opens it as a
#' `status: proposed` issue via [r_challenge_open_issue()] for an organiser to
#' review. Does nothing (and does not error) when no challenge survives
#' verification, so a scheduled run never proposes unverified output.
#'
#' @inheritParams r_challenge_draft_build
#' @param repo Target review repo as `"owner/name"`.
#' @return Invisibly, `TRUE` if a challenge was proposed, else `FALSE`.
#' @export
r_challenge_draft_post <- function(
  difficulty = NULL,
  repo = "rladies/cauldron",
  max_tries = 3L,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  build <- r_challenge_draft_build(
    difficulty = difficulty,
    max_tries = max_tries,
    account_id = account_id,
    api_token = api_token,
    model = model
  )
  if (is.null(build)) {
    cli::cli_alert_info("No verified challenge to propose this week")
    return(invisible(FALSE))
  }
  r_challenge_open_issue(build, repo = repo, source = "ai")
  invisible(TRUE)
}
