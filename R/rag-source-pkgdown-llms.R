#' Gather chunks from pkgdown llms.txt files across an org's R packages
#'
#' Lists every R-language repo in the org, keeps the ones with a root
#' `DESCRIPTION` file, fetches their `llms.txt` from the pkgdown site
#' at `https://rladies.github.io/{repo}/llms.txt`, and chunks each.
#' Requires `GITHUB_TOKEN`. Required `src` fields: `org`.
#'
#' @param src Source spec list.
#' @param pkgdown_base_url Base URL for the org's pkgdown sites.
#' @return List of chunk records.
#' @keywords internal
gather_pkgdown_llms <- function(
  src,
  pkgdown_base_url = src$pkgdown_base_url %||% "https://rladies.github.io"
) {
  token <- Sys.getenv("GITHUB_TOKEN", unset = "")
  if (!nzchar(token)) {
    cli::cli_alert_warning("GITHUB_TOKEN not set - skipping pkgdown-llms")
    return(list())
  }
  cli::cli_alert_info("Discovering R packages in {src$org}")
  candidates <- gh_list_org_r_repos(src$org)
  cli::cli_alert_info(
    "{length(candidates)} R repos, checking for DESCRIPTION"
  )
  repos <- Filter(
    function(r) gh_has_path(r$full_name, "DESCRIPTION"),
    candidates
  )
  cli::cli_alert_info("{length(repos)} repos with root DESCRIPTION")

  per_repo <- lapply(
    repos,
    pkgdown_llms_chunks,
    pkgdown_base_url = pkgdown_base_url
  )
  chunks <- unlist(Filter(Negate(is.null), per_repo), recursive = FALSE) %||%
    list()
  cli::cli_alert_info("pkgdown-llms: {length(chunks)} chunks")
  chunks
}

pkgdown_llms_chunks <- function(repo, pkgdown_base_url) {
  base <- rag_request(pkgdown_base_url) |>
    httr2::req_url_path_append(repo$name)
  text <- base |>
    httr2::req_url_path_append("llms.txt") |>
    rag_fetch_text()
  if (is.null(text) || !nzchar(text)) {
    return(NULL)
  }
  chunks <- chunk_markdown(
    text,
    meta = list(
      repo = repo$full_name,
      path = "llms.txt",
      url = base$url,
      fallback_title = paste0(repo$name, " (R package)")
    )
  )
  assign_chunk_idx(chunks)
}

gh_list_org_r_repos <- function(org) {
  repos <- gh::gh(
    "/orgs/{org}/repos",
    org = org,
    per_page = 100L,
    .limit = Inf
  )
  Filter(
    function(r) {
      !isTRUE(r$archived) && !isTRUE(r$disabled) && identical(r$language, "R")
    },
    repos
  )
}

gh_has_path <- function(full_name, path) {
  result <- tryCatch(
    gh::gh(
      "/repos/{full_name}/contents/{+path}",
      full_name = full_name,
      path = path,
      .accept = "application/vnd.github+json"
    ),
    http_error_404 = function(e) NULL,
    error = function(e) {
      cli::cli_warn("HEAD {full_name}/{path}: {conditionMessage(e)}")
      NULL
    }
  )
  !is.null(result)
}
