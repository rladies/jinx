#' Gather chunks from RLadies+ awesome-creations feeds
#'
#' Reads one or more JSON feeds (packages or content) and emits one
#' chunk per item. Required `src` fields: `repo`, `feeds` (each with
#' `kind` of "package" or "content", and `url`).
#'
#' @param src Source spec list.
#' @param min_chars Drop chunks shorter than this many characters.
#' @return List of chunk records.
#' @keywords internal
gather_awesome_creations <- function(src, min_chars = src$min_chars %or% 60L) {
  per_feed <- lapply(
    src$feeds,
    gather_awesome_feed,
    src = src,
    min_chars = min_chars
  )
  unlist(per_feed, recursive = FALSE) %or% list()
}

#' Fetch one awesome-creations feed and format each item into a chunk
#' @keywords internal
gather_awesome_feed <- function(feed, src, min_chars) {
  items <- rag_fetch_json(rag_request(feed$url))
  if (!is.list(items) || length(items) == 0L) {
    cli::cli_alert_warning("awesome-creations: no array at {feed$url}")
    return(list())
  }
  chunks <- lapply(items, format_awesome_item, feed = feed, src = src)
  chunks <- Filter(
    function(c) !is.null(c) && nchar(c$text) >= min_chars,
    chunks
  )
  cli::cli_alert_info(
    "awesome-creations: {length(chunks)}/{length(items)} from {feed$kind}"
  )
  chunks
}

#' Dispatch an awesome-creations item to the package or content formatter
#' @keywords internal
format_awesome_item <- function(item, feed, src) {
  if (identical(feed$kind, "package")) {
    format_awesome_package(item, src)
  } else {
    format_awesome_content(item, src)
  }
}

#' Build a chunk record for one awesome-creations package entry
#' @keywords internal
format_awesome_package <- function(pkg, src) {
  if (is.null(pkg$name) || !nzchar(pkg$name)) {
    return(NULL)
  }
  url <- pkg$pkdown_url %or% pkg$repo_url
  if (is.null(url) || !nzchar(url)) {
    return(NULL)
  }

  authors <- format_authors(pkg$authors)
  fields <- c(
    Package = pkg$name,
    Title = pkg$title %or% pkg$name,
    Authors = if (nzchar(authors)) authors,
    Repository = pkg$repo_url,
    Documentation = pkg$pkdown_url,
    `Last updated` = pkg$last_updated
  )
  lines <- paste0(names(fields), ": ", fields)
  if (!is.null(pkg$description) && nzchar(pkg$description)) {
    lines <- c(lines, "", trimws(gsub("\\s+", " ", pkg$description)))
  }
  date <- rag_parse_date(pkg$last_updated)
  list(
    text = paste(lines, collapse = "\n"),
    heading = "R package",
    title = paste0(
      pkg$name,
      " - ",
      pkg$title %or% "R package by an RLadies+ member"
    ),
    repo = src$repo,
    path = paste0("package/", pkg$name),
    url = url,
    date = date,
    lastmod = date,
    chunk_idx = 0L
  )
}

#' Build a chunk record for one awesome-creations content entry
#' @keywords internal
format_awesome_content <- function(item, src) {
  if (is.null(item$url) || !nzchar(item$url)) {
    return(NULL)
  }
  url <- normalise_awesome_url(item$url)
  authors <- format_authors(item$authors)
  fields <- c(
    Title = item$title %or% url,
    Type = item$type %or% "content",
    Language = item$language,
    Authors = if (nzchar(authors)) authors
  )
  lines <- paste0(names(fields), ": ", fields)
  if (!is.null(item$description) && nzchar(item$description)) {
    lines <- c(lines, "", trimws(gsub("\\s+", " ", item$description)))
  }
  list(
    text = paste(lines, collapse = "\n"),
    heading = item$type %or% "Community content",
    title = item$title %or% url,
    repo = src$repo,
    path = paste0("content/", slugify_awesome(item$title %or% url)),
    url = url,
    date = 0L,
    lastmod = 0L,
    chunk_idx = 0L
  )
}

#' Collapse a list of author records into a comma-separated names string
#' @keywords internal
format_authors <- function(authors) {
  if (!is.list(authors) || length(authors) == 0L) {
    return("")
  }
  names_v <- vapply(authors, function(a) a$name %or% "", character(1))
  paste(names_v[nzchar(names_v)], collapse = ", ")
}

#' Prefix bare host strings with `https://` so awesome URLs are absolute
#' @keywords internal
normalise_awesome_url <- function(raw) {
  s <- trimws(as.character(raw))
  if (grepl("^https?://", s, ignore.case = TRUE)) {
    return(s)
  }
  paste0("https://", s)
}

#' Slugify a string into a lowercase hyphenated path fragment (max 80 chars)
#' @keywords internal
slugify_awesome <- function(s) {
  s <- gsub("(^-+|-+$)", "", gsub("[^a-z0-9]+", "-", tolower(as.character(s))))
  substr(s, 1L, 80L)
}
