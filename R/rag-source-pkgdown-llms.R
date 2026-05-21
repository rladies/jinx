#' Gather chunks from pkgdown llms.txt files across an org's R packages
#'
#' Lists every R-language repo in the org, keeps the ones with a root
#' `DESCRIPTION` file, fetches their `llms.txt` from the pkgdown site
#' at `https://rladies.github.io/{repo}/llms.txt`, and chunks each.
#' Requires `GITHUB_TOKEN`. Required `src` fields: `org`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_pkgdown_llms <- function(src) {
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

  out <- list()
  for (repo in repos) {
    base_url <- paste0("https://rladies.github.io/", repo$name)
    text <- rag_fetch_text(paste0(base_url, "/llms.txt"))
    if (is.null(text) || !nzchar(text)) {
      next
    }
    chunks <- chunk_markdown(
      text,
      meta = list(
        repo = repo$full_name,
        path = "llms.txt",
        url = base_url,
        fallback_title = paste0(repo$name, " (R package)")
      )
    )
    for (i in seq_along(chunks)) {
      chunks[[i]]$chunk_idx <- i - 1L
      out[[length(out) + 1L]] <- chunks[[i]]
    }
  }
  cli::cli_alert_info("pkgdown-llms: {length(out)} chunks")
  out
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
