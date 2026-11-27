#' Extra chunk indices to delete beyond a private repo's current ones
#'
#' The ids a repository's chunks got are recomputed from the repository
#' as it is now, but it was indexed as it was then. A README that has
#' since been shortened - or deleted outright - leaves vectors behind at
#' indices it no longer produces, so the whole range from zero to a
#' margin past the current end is deleted. Deleting an id the index does
#' not hold is not an error.
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

  # From zero, not from the current chunk count: a repo whose README was
  # deleted produces no README chunks now, and starting the range at the
  # end would leave every chunk it had when indexed in place.
  readme <- Filter(function(chunk) identical(chunk$path, "README.md"), chunks)
  extra <- seq(0L, length(readme) + rag_purge_margin() - 1L)
  ids <- c(
    ids,
    vapply(
      extra,
      function(i) rag_chunk_id(repo$full_name, "README.md", i),
      character(1)
    )
  )

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
    cli::cli_abort(
      paste0(
        "GITHUB_TOKEN is not set, so private repositories cannot be ",
        "identified and their chunks would stay in {.field {index_name}}. ",
        "Set it, or pass {.code purge_private = FALSE} to accept that."
      )
    )
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

  skipped <- character()
  ids <- unique(unlist(
    lapply(private, function(repo) {
      tryCatch(
        rag_private_repo_ids(repo, token),
        error = function(cnd) {
          cli::cli_alert_warning(
            "Could not compute ids for {repo$full_name}: ",
            "{conditionMessage(cnd)}"
          )
          skipped <<- c(skipped, repo$full_name)
          character(0)
        }
      )
    })
  ))

  ids <- ids %||% character()
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

  # After the deletes that did work, so a repo we could reach is still
  # cleaned - but the run goes red, because a skipped repo means private
  # text may still be in the index and a green run would hide that.
  rag_purge_report_skipped(skipped, index_name)

  invisible(length(ids))
}

#' Fail the run when a private repo could not be purged
#'
#' A repository whose ids could not be computed may still have chunks in
#' the index. Warning alone would leave the build green, which is how
#' the exposure went unnoticed in the first place.
#'
#' @param skipped Full names of repositories that were skipped.
#' @param index_name Vectorize index name, for the message.
#' @return Invisibly `NULL`, or an error when anything was skipped.
#' @keywords internal
#' @noRd
rag_purge_report_skipped <- function(skipped, index_name) {
  if (!length(skipped)) {
    return(invisible(NULL))
  }
  cli::cli_abort(
    paste0(
      "Could not purge {length(skipped)} private repositor{?y/ies} from ",
      "{.field {index_name}}: {.val {skipped}}. Their chunks may still be ",
      "in the index."
    )
  )
}
