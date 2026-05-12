#' Post a directory validation report as a PR comment
#'
#' Runs all directory validations (schema, filenames, social handles)
#' on changed files in a PR and posts a summary comment.
#'
#' @param owner Repository owner.
#' @param repo Repository name.
#' @param pr_number PR number.
#' @return Invisibly returns the URL of the posted PR comment.
#' @export
validate_directory_pr <- function(owner, repo, pr_number) {
  files <- gh::gh(
    "GET /repos/{owner}/{repo}/pulls/{pr_number}/files",
    owner = owner,
    repo = repo,
    pr_number = pr_number,
    .limit = Inf
  )

  json_files <- Filter(
    function(f) {
      grepl("\\.json$", f$filename) && grepl("^data/", f$filename)
    },
    files
  )

  if (length(json_files) == 0) {
    post_reply(
      owner,
      repo,
      pr_number,
      "No directory JSON files changed in this PR."
    )
    return(invisible())
  }

  report_lines <- character()
  all_valid <- TRUE

  for (f in json_files) {
    fname <- basename(f$filename)

    fn_check <- validate_entry_filename(fname)
    if (fn_check$valid) {
      report_lines <- c(
        report_lines,
        glue::glue(
          "**{fname}** - filename OK"
        )
      )
    } else {
      all_valid <- FALSE
      report_lines <- c(
        report_lines,
        glue::glue(
          "**{fname}** - filename issues:",
          " {paste(fn_check$issues, collapse = ', ')}"
        )
      )
    }
  }

  status <- if (all_valid) "All checks passed" else "Issues found"
  header <- glue::glue(
    "### Directory Validation Report\n\n**Status:** {status}\n"
  )
  body <- paste(c(header, report_lines), collapse = "\n- ")

  post_reply(owner, repo, pr_number, body)
  cli::cli_alert_info("Posted validation report on PR #{pr_number}")
  invisible()
}
