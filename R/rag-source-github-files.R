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
  root <- Sys.getenv(src$root_env %or% "JINX_PATH", unset = "..")
  per_file <- lapply(src$files, local_file_chunks, root = root, src = src)
  chunks <- unlist(Filter(Negate(is.null), per_file), recursive = FALSE) %or%
    list()
  cli::cli_alert_info("github-files: {length(chunks)} chunks from {src$repo}")
  chunks
}

#' Read a local markdown file and chunk it, attaching repo/url metadata
#' @keywords internal
local_file_chunks <- function(entry, root, src) {
  abs_path <- file.path(root, entry$path)
  if (!file.exists(abs_path)) {
    cli::cli_warn("github-files: {entry$path} missing at {abs_path}")
    return(NULL)
  }
  md <- paste(
    readLines(abs_path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  chunks <- chunk_markdown(
    md,
    meta = list(
      repo = src$repo,
      path = entry$path,
      url = entry$url,
      fallback_title = entry$title %or% entry$path
    )
  )
  assign_chunk_idx(chunks)
}

#' Assign zero-based `chunk_idx` to each element of a chunk list
#' @keywords internal
assign_chunk_idx <- function(chunks) {
  Map(
    function(chunk, idx) {
      chunk$chunk_idx <- idx
      chunk
    },
    chunks,
    seq_along(chunks) - 1L
  )
}
