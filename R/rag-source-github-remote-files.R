GH_API <- "https://api.github.com"

#' Build a base authenticated GitHub API request
#'
#' Returns an [httr2::request] pointed at the GitHub REST root with
#' the bearer token, API version, and a default JSON `Accept` header
#' attached. Callers append path segments and override `Accept` per
#' endpoint (e.g. `application/vnd.github.raw` for raw file
#' contents).
#'
#' @param token GitHub bearer token.
#' @return [httr2::request] object.
#' @keywords internal
github_request <- function(token) {
  httr2::request(GH_API) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      Accept = "application/vnd.github+json",
      `X-GitHub-Api-Version` = "2022-11-28"
    ) |>
    httr2::req_user_agent(RAG_USER_AGENT)
}

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
  per_file <- lapply(src$files, remote_file_chunks, src = src, token = token)
  chunks <- unlist(Filter(Negate(is.null), per_file), recursive = FALSE) %||%
    list()
  cli::cli_alert_info(
    "github-remote-files: {length(chunks)} chunks from {src$repo}"
  )
  chunks
}

remote_file_chunks <- function(entry, src, token) {
  md <- github_request(token) |>
    httr2::req_url_path_append("repos", src$repo, "contents", entry$path) |>
    httr2::req_headers(Accept = "application/vnd.github.raw") |>
    rag_fetch_text()
  if (is.null(md)) {
    cli::cli_warn("github-remote-files: {src$repo}/{entry$path} not found")
    return(NULL)
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
  assign_chunk_idx(chunks)
}
