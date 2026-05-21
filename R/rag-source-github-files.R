#' Gather chunks from local files in a checked-out repo
#'
#' Reads files from disk (relative to `src$root_env` env var, default
#' `JINX_PATH`) and runs them through `chunk_markdown()`. Required
#' `src` fields: `repo`, `files` (each with `path`, `url`, optional
#' `title`).
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_github_files <- function(src) {
  root_env <- src$root_env %||% "JINX_PATH"
  root <- Sys.getenv(root_env, unset = "..")
  out <- list()
  for (entry in src$files) {
    abs_path <- file.path(root, entry$path)
    if (!file.exists(abs_path)) {
      cli::cli_warn("github-files: {entry$path} missing at {abs_path}")
      next
    }
    md <- readLines(abs_path, warn = FALSE, encoding = "UTF-8") |>
      paste(collapse = "\n")
    chunks <- chunk_markdown(
      md,
      meta = list(
        repo = src$repo,
        path = entry$path,
        url = entry$url,
        fallback_title = entry$title %||% entry$path
      )
    )
    for (i in seq_along(chunks)) {
      chunks[[i]]$chunk_idx <- i - 1L
      out[[length(out) + 1L]] <- chunks[[i]]
    }
  }
  cli::cli_alert_info("github-files: {length(out)} chunks from {src$repo}")
  out
}
