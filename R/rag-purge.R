#' Extra chunk indices to delete beyond a private repo's current ones
#'
#' The ids a repository's chunks got are recomputed from the repository
#' as it is now, but it was indexed as it was then. A README that has
#' since been shortened leaves vectors behind at the indices it no
#' longer produces, so a margin is deleted past the end. Deleting an id
#' the index does not hold is not an error.
#' @keywords internal
#' @noRd
rag_purge_margin <- function() 50L

#' Vector ids a private repository would have been indexed under
#'
#' Computed with the same functions that produced them, so the ids match
#' whatever the indexer did at the time rather than a guess at its
#' scheme.
#'
#' @param repo A repository record from the GitHub API.
#' @param token GitHub token.
#' @return Character vector of vector ids.
#' @keywords internal
#' @noRd
rag_private_repo_ids <- function(repo, token) {
  chunks <- repo_to_chunks(repo, token)
  ids <- vapply(
    chunks,
    function(chunk) rag_chunk_id(chunk$repo, chunk$path, chunk$chunk_idx),
    character(1)
  )

  readme <- Filter(function(chunk) identical(chunk$path, "README.md"), chunks)
  if (length(readme)) {
    extra <- seq(
      length(readme),
      length(readme) + rag_purge_margin() - 1L
    )
    ids <- c(
      ids,
      vapply(
        extra,
        function(i) rag_chunk_id(repo$full_name, "README.md", i),
        character(1)
      )
    )
  }

  unique(ids)
}

#' Delete any private repository's chunks from the index
#'
#' The org source indexed every repository the App could see, private
#' ones included, so names, descriptions and README text that is private
#' on GitHub reached an index that answers questions in Slack. Filtering
#' the gather stops that happening again, but the index is upserted by
#' id rather than rebuilt, so what is already in it stays until it is
#' deleted.
#'
#' Run on every build rather than once: it is idempotent, it costs one
#' request per batch, and a repository that goes private later is then
#' cleaned up without anyone having to notice.
#'
#' @param org GitHub organization.
#' @param account_id Cloudflare account ID.
#' @param api_token Cloudflare API token.
#' @param index_name Vectorize index name.
#' @param batch_size Ids per delete call.
#' @return Invisibly, the number of ids deleted.
#' @export
rag_purge_private <- function(
  org,
  account_id,
  api_token,
  index_name,
  batch_size = 500L
) {
  token <- Sys.getenv("GITHUB_TOKEN", unset = "")
  if (!nzchar(token)) {
    cli::cli_alert_warning("GITHUB_TOKEN not set - skipping private purge")
    return(invisible(0L))
  }

  repos <- gh::gh(
    "/orgs/{org}/repos",
    org = org,
    per_page = 100L,
    .limit = Inf
  )
  private <- Filter(function(r) isTRUE(r$private), repos)
  if (!length(private)) {
    cli::cli_alert_info("No private repos to purge")
    return(invisible(0L))
  }

  ids <- unique(unlist(
    lapply(private, function(repo) {
      tryCatch(
        rag_private_repo_ids(repo, token),
        error = function(cnd) {
          cli::cli_alert_warning(
            "Could not compute ids for {repo$full_name}: ",
            "{conditionMessage(cnd)}"
          )
          character(0)
        }
      )
    })
  ))
  if (!length(ids)) {
    return(invisible(0L))
  }

  batches <- split(ids, ceiling(seq_along(ids) / batch_size))
  for (batch in batches) {
    cloudflare_vectorize_delete_by_ids(
      ids = batch,
      account_id = account_id,
      api_token = api_token,
      index_name = index_name
    )
  }

  cli::cli_alert_success(
    "Purged {length(ids)} id{?s} for {length(private)} private repo{?s}"
  )
  invisible(length(ids))
}
