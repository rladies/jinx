#' Gather chunks from a GitHub org's teams, repo metadata, and READMEs
#'
#' One chunk per team, one chunk per repo metadata block, plus chunked
#' README content for each live repo. Requires `GITHUB_TOKEN`. Required
#' `src` fields: `org`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_github_org <- function(src) {
  token <- Sys.getenv("GITHUB_TOKEN", unset = "")
  if (!nzchar(token)) {
    cli::cli_alert_warning("GITHUB_TOKEN not set - skipping github-org")
    return(list())
  }
  cli::cli_alert_info("Fetching org data for {src$org}")

  teams <- gh::gh(
    "/orgs/{org}/teams",
    org = src$org,
    per_page = 100L,
    .limit = Inf
  )
  repos <- gh::gh(
    "/orgs/{org}/repos",
    org = src$org,
    per_page = 100L,
    .limit = Inf
  )
  live_repos <- Filter(
    function(r) !isTRUE(r$archived) && !isTRUE(r$disabled),
    repos
  )
  cli::cli_alert_info(
    "{length(teams)} teams, {length(repos)} repos ({length(live_repos)} live)"
  )

  out <- list()

  for (team in teams) {
    if (!is.null(team$privacy) && !identical(team$privacy, "closed")) {
      next
    }
    out[[length(out) + 1L]] <- list(
      text = render_team_text(team),
      heading = "",
      title = paste0("Team: ", team$name),
      repo = paste0(src$org, "/.teams"),
      path = team$slug,
      url = team$html_url %||%
        paste0("https://github.com/orgs/", src$org, "/teams/", team$slug),
      date = 0L,
      lastmod = 0L,
      chunk_idx = 0L
    )
  }

  for (repo in live_repos) {
    out[[length(out) + 1L]] <- list(
      text = render_repo_meta_text(repo),
      heading = "",
      title = repo$full_name,
      repo = repo$full_name,
      path = "_meta",
      url = repo$html_url,
      date = 0L,
      lastmod = 0L,
      chunk_idx = 0L
    )

    readme <- gh_fetch_readme(repo$full_name)
    if (!is.null(readme) && nzchar(trimws(readme))) {
      readme_chunks <- chunk_markdown(
        readme,
        meta = list(
          repo = repo$full_name,
          path = "README.md",
          url = repo$html_url,
          fallback_title = paste0(repo$full_name, " README")
        )
      )
      for (i in seq_along(readme_chunks)) {
        readme_chunks[[i]]$chunk_idx <- i - 1L
        out[[length(out) + 1L]] <- readme_chunks[[i]]
      }
    }
  }

  cli::cli_alert_info("github-org: {length(out)} chunks")
  out
}

render_team_text <- function(team) {
  lines <- c(
    paste0("Team name: ", team$name),
    paste0("Slug: ", team$slug),
    paste0("Description: ", team$description %||% "(no description)")
  )
  if (!is.null(team$parent)) {
    lines <- c(lines, paste0("Parent team: ", team$parent$name))
  }
  if (!is.null(team$privacy)) {
    lines <- c(lines, paste0("Visibility: ", team$privacy))
  }
  paste(lines, collapse = "\n")
}

render_repo_meta_text <- function(repo) {
  topics <- if (length(repo$topics)) {
    paste(unlist(repo$topics), collapse = ", ")
  } else {
    "(none)"
  }
  lines <- c(
    paste0("Repository: ", repo$full_name),
    paste0("Description: ", repo$description %||% "(no description)"),
    paste0("Primary language: ", repo$language %||% "n/a"),
    paste0("Topics: ", topics),
    paste0("License: ", repo$license$spdx_id %||% "n/a"),
    paste0("Homepage: ", repo$homepage %||% repo$html_url),
    paste0("Visibility: ", if (isTRUE(repo$private)) "private" else "public")
  )
  paste(lines, collapse = "\n")
}

gh_fetch_readme <- function(full_name) {
  tryCatch(
    {
      result <- gh::gh(
        "/repos/{full_name}/readme",
        full_name = full_name,
        .accept = "application/vnd.github.raw"
      )
      as.character(result)
    },
    http_error_404 = function(e) NULL,
    error = function(e) {
      cli::cli_warn("README {full_name}: {conditionMessage(e)}")
      NULL
    }
  )
}
