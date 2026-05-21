#' Gather chunks from individually-listed files in a remote GitHub repo
#'
#' Fetches the raw contents of each file via the GitHub API and runs
#' them through `chunk_markdown()`. Requires `GITHUB_TOKEN` in the
#' environment. Required `src` fields: `repo`, `files`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_github_remote_files <- function(src) {
  token <- Sys.getenv("GITHUB_TOKEN", unset = "")
  if (!nzchar(token)) {
    cli::cli_alert_warning(
      "GITHUB_TOKEN not set - skipping github-remote-files"
    )
    return(list())
  }
  out <- list()
  for (entry in src$files) {
    md <- gh_fetch_raw_file(src$repo, entry$path, token)
    if (is.null(md)) {
      cli::cli_warn("github-remote-files: {src$repo}/{entry$path} not found")
      next
    }
    chunks <- chunk_markdown(
      md,
      meta = list(
        repo = src$repo,
        path = entry$path,
        url = entry$url,
        fallback_title = entry$title %||% paste0(src$repo, "/", entry$path)
      )
    )
    for (i in seq_along(chunks)) {
      chunks[[i]]$chunk_idx <- i - 1L
      out[[length(out) + 1L]] <- chunks[[i]]
    }
  }
  cli::cli_alert_info(
    "github-remote-files: {length(out)} chunks from {src$repo}"
  )
  out
}

gh_fetch_raw_file <- function(repo, path, token) {
  url <- paste0(
    "https://api.github.com/repos/",
    repo,
    "/contents/",
    path
  )
  rag_fetch_text(
    url,
    headers = c(
      Authorization = paste("Bearer", token),
      Accept = "application/vnd.github.raw",
      `X-GitHub-Api-Version` = "2022-11-28"
    )
  )
}
