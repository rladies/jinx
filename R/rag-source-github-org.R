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

  team_chunks <- Filter(
    Negate(is.null),
    lapply(teams, team_to_chunk, src = src)
  )
  repo_chunks <- unlist(
    lapply(live_repos, repo_to_chunks, token = token),
    recursive = FALSE
  ) %||%
    list()

  chunks <- c(team_chunks, repo_chunks)
  cli::cli_alert_info("github-org: {length(chunks)} chunks")
  chunks
}

team_to_chunk <- function(team, src) {
  if (!is.null(team$privacy) && !identical(team$privacy, "closed")) {
    return(NULL)
  }
  list(
    text = render_team_text(team),
    heading = "",
    title = paste0("Team: ", team$name),
    repo = paste0(src$org, "/.teams"),
    path = team$slug,
    url = team$html_url %||%
      (httr2::request("https://github.com") |>
        httr2::req_url_path_append("orgs", src$org, "teams", team$slug) |>
        _$url),
    date = 0L,
    lastmod = 0L,
    chunk_idx = 0L
  )
}

repo_to_chunks <- function(repo, token) {
  meta_chunk <- list(
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
  if (is.null(readme) || !nzchar(trimws(readme))) {
    return(list(meta_chunk))
  }
  readme_chunks <- assign_chunk_idx(chunk_markdown(
    readme,
    meta = list(
      repo = repo$full_name,
      path = "README.md",
      url = repo$html_url,
      fallback_title = paste0(repo$full_name, " README")
    )
  ))
  c(list(meta_chunk), readme_chunks)
}

render_team_text <- function(team) {
  fields <- c(
    `Team name` = team$name,
    Slug = team$slug,
    Description = team$description %||% "(no description)",
    `Parent team` = if (!is.null(team$parent)) team$parent$name,
    Visibility = team$privacy
  )
  paste(paste0(names(fields), ": ", fields), collapse = "\n")
}

render_repo_meta_text <- function(repo) {
  topics <- if (length(repo$topics)) {
    paste(unlist(repo$topics), collapse = ", ")
  } else {
    "(none)"
  }
  fields <- c(
    Repository = repo$full_name,
    Description = repo$description %||% "(no description)",
    `Primary language` = repo$language %||% "n/a",
    Topics = topics,
    License = repo$license$spdx_id %||% "n/a",
    Homepage = repo$homepage %||% repo$html_url,
    Visibility = if (isTRUE(repo$private)) "private" else "public"
  )
  paste(paste0(names(fields), ": ", fields), collapse = "\n")
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
