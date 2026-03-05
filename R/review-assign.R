#' Run all PR review automation
#'
#' Assigns reviewers, labels the PR, and posts a checklist comment.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number Pull request number.
#' @export
review_pr <- function(owner, repo, pr_number) {
  cli::cli_h2("Reviewing PR #{pr_number} in {owner}/{repo}")

  pr <- gh::gh(
    "GET /repos/{owner}/{repo}/pulls/{pr_number}",
    owner = owner, repo = repo, pr_number = pr_number
  )

  files <- gh::gh(
    "GET /repos/{owner}/{repo}/pulls/{pr_number}/files",
    owner = owner, repo = repo, pr_number = pr_number,
    .limit = Inf
  )

  file_paths <- vapply(files, function(f) f$filename, character(1))

  labels <- label_pr(owner, repo, pr_number, file_paths)
  reviewers <- assign_reviewers(owner, repo, pr_number, file_paths, pr$user$login)
  post_checklist(owner, repo, pr_number, file_paths)

  cli::cli_alert_success(
    "PR #{pr_number}: {length(labels)} labels, {length(reviewers)} reviewers assigned"
  )
  invisible(list(labels = labels, reviewers = reviewers))
}

#' Assign reviewers based on file paths
#'
#' Uses review rules config to match changed files to reviewers.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @param file_paths Changed file paths.
#' @param author PR author login (excluded from reviewers).
#' @return Character vector of assigned reviewer logins.
assign_reviewers <- function(owner, repo, pr_number, file_paths, author = NULL) {
  rules <- tryCatch(load_review_rules(), error = function(e) NULL)
  if (is.null(rules)) return(character(0))

  reviewers <- character(0)
  for (rule in rules$rules) {
    pattern <- rule$pattern
    matched <- any(grepl(pattern, file_paths))
    if (matched && !is.null(rule$reviewers)) {
      reviewers <- unique(c(reviewers, unlist(rule$reviewers)))
    }
  }

  if (!is.null(rules$defaults$reviewers)) {
    reviewers <- unique(c(reviewers, unlist(rules$defaults$reviewers)))
  }

  reviewers <- setdiff(reviewers, author)
  if (length(reviewers) == 0) return(character(0))

  max_reviewers <- rules$defaults$max_reviewers %||% 2
  if (length(reviewers) > max_reviewers) {
    reviewers <- sample(reviewers, max_reviewers)
  }

  tryCatch({
    gh::gh(
      "POST /repos/{owner}/{repo}/pulls/{pr_number}/requested_reviewers",
      owner = owner, repo = repo, pr_number = pr_number,
      reviewers = as.list(reviewers)
    )
    cli::cli_alert_info("Assigned reviewers: {paste(reviewers, collapse = ', ')}")
  }, error = function(e) {
    cli::cli_alert_warning("Failed to assign reviewers: {e$message}")
  })

  reviewers
}
