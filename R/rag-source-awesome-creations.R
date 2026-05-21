AWESOME_MIN_CHARS <- 60L

#' Gather chunks from RLadies+ awesome-creations feeds
#'
#' Reads one or more JSON feeds (packages or content) and emits one
#' chunk per item. Required `src` fields: `repo`, `feeds` (each with
#' `kind` of "package" or "content", and `url`).
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_awesome_creations <- function(src) {
  out <- list()
  for (feed in src$feeds) {
    items <- rag_fetch_json(feed$url)
    if (!is.list(items) || length(items) == 0L) {
      cli::cli_alert_warning("awesome-creations: no array at {feed$url}")
      next
    }
    kept <- 0L
    for (item in items) {
      chunk <- format_awesome_item(item, feed, src)
      if (is.null(chunk)) {
        next
      }
      if (nchar(chunk$text) < AWESOME_MIN_CHARS) {
        next
      }
      out[[length(out) + 1L]] <- chunk
      kept <- kept + 1L
    }
    cli::cli_alert_info(
      "awesome-creations: {kept}/{length(items)} from {feed$kind}"
    )
  }
  out
}

format_awesome_item <- function(item, feed, src) {
  if (identical(feed$kind, "package")) {
    format_awesome_package(item, src)
  } else {
    format_awesome_content(item, src)
  }
}

format_awesome_package <- function(pkg, src) {
  if (is.null(pkg$name) || !nzchar(pkg$name)) {
    return(NULL)
  }
  url <- pkg$pkdown_url %||% pkg$repo_url
  if (is.null(url) || !nzchar(url)) {
    return(NULL)
  }
  lines <- c(
    paste0("Package: ", pkg$name),
    paste0("Title: ", pkg$title %||% pkg$name)
  )
  authors <- format_authors(pkg$authors)
  if (nzchar(authors)) {
    lines <- c(lines, paste0("Authors: ", authors))
  }
  if (!is.null(pkg$repo_url)) {
    lines <- c(lines, paste0("Repository: ", pkg$repo_url))
  }
  if (!is.null(pkg$pkdown_url)) {
    lines <- c(lines, paste0("Documentation: ", pkg$pkdown_url))
  }
  if (!is.null(pkg$last_updated)) {
    lines <- c(lines, paste0("Last updated: ", pkg$last_updated))
  }
  if (!is.null(pkg$description) && nzchar(pkg$description)) {
    lines <- c(lines, "", trimws(gsub("\\s+", " ", pkg$description)))
  }
  date <- rag_parse_date(pkg$last_updated)
  list(
    text = paste(lines, collapse = "\n"),
    heading = "R package",
    title = paste0(
      pkg$name,
      " — ",
      pkg$title %||% "R package by an RLadies+ member"
    ),
    repo = src$repo,
    path = paste0("package/", pkg$name),
    url = url,
    date = date,
    lastmod = date,
    chunk_idx = 0L
  )
}

format_awesome_content <- function(item, src) {
  if (is.null(item$url) || !nzchar(item$url)) {
    return(NULL)
  }
  url <- normalise_awesome_url(item$url)
  lines <- c(
    paste0("Title: ", item$title %||% url),
    paste0("Type: ", item$type %||% "content")
  )
  if (!is.null(item$language)) {
    lines <- c(lines, paste0("Language: ", item$language))
  }
  authors <- format_authors(item$authors)
  if (nzchar(authors)) {
    lines <- c(lines, paste0("Authors: ", authors))
  }
  if (!is.null(item$description) && nzchar(item$description)) {
    lines <- c(lines, "", trimws(gsub("\\s+", " ", item$description)))
  }
  list(
    text = paste(lines, collapse = "\n"),
    heading = item$type %||% "Community content",
    title = item$title %||% url,
    repo = src$repo,
    path = paste0("content/", slugify_awesome(item$title %||% url)),
    url = url,
    date = 0L,
    lastmod = 0L,
    chunk_idx = 0L
  )
}

format_authors <- function(authors) {
  if (!is.list(authors) || length(authors) == 0L) {
    return("")
  }
  names_v <- vapply(authors, function(a) a$name %||% "", character(1))
  paste(names_v[nzchar(names_v)], collapse = ", ")
}

normalise_awesome_url <- function(raw) {
  s <- trimws(as.character(raw))
  if (grepl("^https?://", s, ignore.case = TRUE)) {
    return(s)
  }
  paste0("https://", s)
}

slugify_awesome <- function(s) {
  s <- tolower(as.character(s))
  s <- gsub("[^a-z0-9]+", "-", s)
  s <- gsub("(^-+|-+$)", "", s)
  substr(s, 1L, 80L)
}
