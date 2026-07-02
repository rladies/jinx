#' Build a blog entry list from a URL's OpenGraph metadata
#'
#' Fetches the page and assembles a JSON-ready entry compatible with the
#' awesome-rladies-creations content format. The author defaults to the
#' page's `article:author`/`author` metadata when not supplied.
#'
#' @param url Blog URL.
#' @param language Language code. Defaults to `"en"`.
#' @param author_name Author name. When `NULL`, taken from page metadata.
#' @return A named list describing the entry.
#' @keywords internal
#' @noRd
blog_build_entry <- function(url, language = "en", author_name = NULL) {
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(15) |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_abort("Failed to fetch {.url {url}}: {e$message}")
    }
  )

  html <- httr2::resp_body_string(resp)

  title <- extract_meta(html, "og:title") %||%
    extract_html_title(html) %||%
    "Untitled"
  description <- extract_meta(html, "og:description") %||%
    extract_meta(html, "description") %||%
    ""
  image <- extract_meta(html, "og:image") %||% ""
  rss_feed <- detect_rss_feed(html, url)
  author <- author_name %||%
    extract_meta(html, "article:author") %||%
    extract_meta(html, "author") %||%
    ""

  entry <- list(
    title = title,
    url = url,
    type = "blog",
    photo_url = image,
    description = description,
    language = language,
    authors = list(
      list(name = author, social_media = list(list()))
    )
  )
  if (!is.null(rss_feed)) {
    entry$rss_feed <- rss_feed
  }
  entry
}

#' Slugified `{domain}.json` filename for a blog URL
#' @keywords internal
#' @noRd
blog_entry_filename <- function(url) {
  domain <- sub("/.*$", "", sub("^https?://", "", url))
  paste0(gsub("[^a-z0-9.-]", "", tolower(domain)), ".json")
}

#' Auto-generate a blog entry JSON file from a URL
#'
#' Fetches OpenGraph metadata from the URL and writes a JSON entry
#' compatible with awesome-rladies-creations format.
#'
#' @param url Blog URL.
#' @param language Language code. Defaults to `"en"`.
#' @param author_name Author name. Required.
#' @param output_dir Directory to write the JSON file. Defaults to `"."`.
#' @return File path of the created JSON (invisibly).
#' @export
blog_create_entry <- function(
  url,
  language = "en",
  author_name,
  output_dir = "."
) {
  entry <- blog_build_entry(url, language, author_name)
  filepath <- file.path(output_dir, blog_entry_filename(url))
  jsonlite::write_json(entry, filepath, auto_unbox = TRUE, pretty = TRUE)

  cli::cli_alert_success("Created blog entry: {.path {basename(filepath)}}")
  invisible(filepath)
}

#' Add a community blog entry via a pull request
#'
#' Builds an entry from the URL's metadata and opens a PR adding it to the
#' awesome-rladies-creations content directory. If an entry for the URL's
#' domain already exists, no PR is opened.
#'
#' @param url Blog URL.
#' @param org,repo,content_path Location of the blog entry JSON files.
#' @param language Language code. Defaults to `"en"`.
#' @param author_name Author name. When `NULL`, taken from page metadata.
#' @param base Base branch. Defaults to `"main"`.
#' @return A list with `status` (`"created"` or `"exists"`), `filename`,
#'   and `url` (the PR URL when created).
#' @export
blog_add_pr <- function(
  url,
  org = "rladies",
  repo = "awesome-rladies-creations",
  content_path = "data/content",
  language = "en",
  author_name = NULL,
  base = "main"
) {
  filename <- blog_entry_filename(url)
  path <- glue::glue("{content_path}/{filename}")

  existing <- tryCatch(
    gh::gh(
      "GET /repos/{owner}/{repo}/contents/{path}",
      owner = org,
      repo = repo,
      path = path,
      ref = base
    ),
    error = function(e) NULL
  )
  if (!is.null(existing)) {
    return(list(status = "exists", filename = filename, url = NULL))
  }

  entry <- blog_build_entry(url, language, author_name)
  json <- jsonlite::toJSON(entry, auto_unbox = TRUE, pretty = TRUE)

  branch <- paste0("jinx/blog-add-", sub("\\.json$", "", filename))
  gh_branch_upsert(org, repo, branch, base = base)

  gh::gh(
    "PUT /repos/{owner}/{repo}/contents/{path}",
    owner = org,
    repo = repo,
    path = path,
    message = glue::glue("Add blog entry: {entry$title}"),
    content = jsonlite::base64_enc(charToRaw(as.character(json))),
    branch = branch
  )

  pr_url <- gh_open_or_update_pr(
    org,
    repo,
    branch,
    base = base,
    title = glue::glue("Add blog: {entry$title}"),
    body = glue::glue(
      "Auto-generated blog entry from {url}\n\n",
      "Please verify the title, description, author, and RSS feed ",
      "before merging.\n\n_Created by jinx_"
    )
  )

  list(status = "created", filename = filename, url = pr_url)
}

extract_meta <- function(html, property) {
  pattern <- sprintf(
    '<meta[^>]*(?:property|name)=["\']%s["\'][^>]*content=["\']([^"\']*)["\']',
    property
  )
  match <- regmatches(html, regexec(pattern, html, perl = TRUE))[[1]]
  if (length(match) >= 2) match[2] else NULL
}

extract_html_title <- function(html) {
  match <- regmatches(html, regexec("<title[^>]*>([^<]+)</title>", html))[[1]]
  if (length(match) >= 2) trimws(match[2]) else NULL
}

detect_rss_feed <- function(html, base_url) {
  pattern <- paste0(
    '<link[^>]*type=["\']application/(?:rss|atom)\\+xml["\']',
    '[^>]*href=["\']([^"\']*)["\']'
  )
  match <- regmatches(html, regexec(pattern, html, perl = TRUE))[[1]]
  if (length(match) >= 2) {
    feed <- match[2]
    if (!grepl("^https?://", feed)) {
      feed <- sprintf("%s/%s", sub("/$", "", base_url), sub("^/", "", feed))
    }
    feed
  } else {
    NULL
  }
}
