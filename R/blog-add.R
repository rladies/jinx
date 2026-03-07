#' Auto-generate a blog entry JSON from a URL
#'
#' Fetches OpenGraph metadata from the URL and creates a JSON entry
#' compatible with awesome-rladies-blogs format.
#'
#' @param url Blog URL.
#' @param language Language code. Defaults to `"en"`.
#' @param author_name Author name. Required.
#' @param output_dir Directory to write the JSON file. Defaults to `"."`.
#' @return File path of the created JSON (invisibly).
#' @export
create_blog_entry <- function(
  url,
  language = "en",
  author_name,
  output_dir = "."
) {
  resp <- tryCatch(
    {
      httr2::request(url) |>
        httr2::req_timeout(15) |>
        httr2::req_perform()
    },
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

  domain <- sub("^https?://", "", sub("/.*$", "", url))
  filename <- paste0(gsub("[^a-z0-9.-]", "", tolower(domain)), ".json")

  entry <- list(
    title = title,
    url = url,
    rss_feed = rss_feed,
    type = "blog",
    photo_url = image,
    description = description,
    language = language,
    authors = list(
      list(
        name = author_name,
        social_media = list(list())
      )
    )
  )

  filepath <- file.path(output_dir, filename)
  jsonlite::write_json(entry, filepath, auto_unbox = TRUE, pretty = TRUE)

  cli::cli_alert_success("Created blog entry: {.path {filename}}")
  invisible(filepath)
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
  pattern <- '<link[^>]*type=["\']application/(?:rss|atom)\\+xml["\'][^>]*href=["\']([^"\']*)["\']'
  match <- regmatches(html, regexec(pattern, html, perl = TRUE))[[1]]
  if (length(match) >= 2) {
    feed <- match[2]
    if (!grepl("^https?://", feed)) {
      feed <- paste0(sub("/$", "", base_url), "/", sub("^/", "", feed))
    }
    feed
  } else {
    NULL
  }
}
