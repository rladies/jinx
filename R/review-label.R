#' Auto-label a PR based on changed file paths
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @param file_paths Character vector of changed file paths.
#' @return Character vector of applied labels.
#' @keywords internal
#' @noRd
label_pr <- function(owner, repo, pr_number, file_paths) {
  labels_config <- tryCatch(load_labels_config(), error = function(e) NULL)
  if (is.null(labels_config)) {
    return(character(0))
  }

  matched_labels <- character(0)
  for (mapping in labels_config$mappings) {
    pattern <- mapping$pattern
    if (any(grepl(pattern, file_paths))) {
      matched_labels <- c(matched_labels, mapping$label)
    }
  }

  matched_labels <- unique(matched_labels)
  if (length(matched_labels) == 0) {
    return(character(0))
  }

  tryCatch(
    {
      gh::gh(
        "POST /repos/{owner}/{repo}/issues/{issue_number}/labels",
        owner = owner,
        repo = repo,
        issue_number = pr_number,
        labels = as.list(matched_labels)
      )
      cli::cli_alert_info(
        "Applied labels: {paste(matched_labels, collapse = ', ')}"
      )
    },
    error = function(e) {
      cli::cli_alert_warning("Failed to apply labels: {e$message}")
    }
  )

  matched_labels
}
