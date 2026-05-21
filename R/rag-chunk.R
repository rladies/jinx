#' Chunk markdown into retrieval-sized pieces
#'
#' Splits a markdown document by H1/H2 sections, then packs paragraphs
#' into chunks of roughly `target_chars` characters. Returns a list of
#' chunk records with heading, title, and lastmod metadata.
#'
#' @param markdown Markdown text (may include YAML frontmatter).
#' @param meta Named list with `repo`, `path`, `url`, `fallback_title`,
#'   optional `date`, `lastmod` (both unix seconds).
#' @param target_chars Approximate target chunk size.
#' @param min_chars Minimum chunk size; smaller chunks are dropped.
#' @return List of chunk records (one list per chunk).
#' @export
chunk_markdown <- function(
  markdown,
  meta,
  target_chars = 1800,
  min_chars = 200
) {
  parts <- strip_frontmatter(markdown)
  sections <- split_by_sections(parts$body)
  date <- meta$date %||% parse_unix_date(parts$frontmatter$date)
  lastmod <- meta$lastmod %||%
    parse_unix_date(parts$frontmatter$lastmod) %||%
    date

  out <- list()
  for (section in sections) {
    pieces <- split_to_target(section$body, target_chars)
    for (piece in pieces) {
      text <- trimws(piece)
      if (nchar(text) < min_chars) {
        next
      }
      out[[length(out) + 1L]] <- list(
        text = text,
        heading = section$heading,
        title = parts$frontmatter$title %||% meta$fallback_title %||% "",
        repo = meta$repo,
        path = meta$path,
        url = meta$url,
        date = date %||% 0L,
        lastmod = lastmod %||% 0L
      )
    }
  }
  out
}

#' @keywords internal
strip_frontmatter <- function(md) {
  if (length(md) != 1L || !nzchar(md)) {
    return(list(body = if (length(md)) md else "", frontmatter = list()))
  }
  m <- regmatches(
    md,
    regexec("^---\r?\n((?:.|\n)*?)\r?\n---\r?\n((?:.|\n)*)$", md, perl = TRUE)
  )[[1]]
  if (length(m) < 3) {
    return(list(body = md, frontmatter = list()))
  }
  fm <- tryCatch(yaml::yaml.load(m[2]), error = function(e) list())
  if (!is.list(fm)) {
    fm <- list()
  }
  list(body = m[3], frontmatter = fm)
}

#' @keywords internal
split_by_sections <- function(body) {
  lines <- strsplit(body, "\r?\n", perl = TRUE)[[1]]
  sections <- list()
  current <- list(heading = "", body = "")
  for (line in lines) {
    h <- regmatches(line, regexec("^(#{1,3})\\s+(.*)$", line))[[1]]
    if (length(h) == 3 && nchar(h[2]) <= 2) {
      if (nzchar(trimws(current$body))) {
        sections[[length(sections) + 1L]] <- current
      }
      current <- list(heading = trimws(h[3]), body = "")
    } else {
      current$body <- paste0(current$body, line, "\n")
    }
  }
  if (nzchar(trimws(current$body))) {
    sections[[length(sections) + 1L]] <- current
  }
  sections
}

#' @keywords internal
split_to_target <- function(text, target) {
  if (nchar(text) <= target) {
    return(text)
  }
  paragraphs <- strsplit(text, "\n\\s*\n", perl = TRUE)[[1]]
  out <- character()
  buf <- ""
  for (p in paragraphs) {
    if (nchar(p) > target) {
      if (nzchar(buf)) {
        out <- c(out, buf)
        buf <- ""
      }
      out <- c(out, hard_split(p, target))
      next
    }
    candidate <- if (nzchar(buf)) paste0(buf, "\n\n", p) else p
    if (nzchar(buf) && nchar(candidate) > target) {
      out <- c(out, buf)
      buf <- p
    } else {
      buf <- candidate
    }
  }
  if (nzchar(buf)) {
    out <- c(out, buf)
  }
  out
}

#' @keywords internal
hard_split <- function(text, target) {
  sentences <- strsplit(text, "(?<=[.!?])\\s+", perl = TRUE)[[1]]
  out <- character()
  buf <- ""
  for (s in sentences) {
    if (nchar(s) > target) {
      if (nzchar(buf)) {
        out <- c(out, buf)
        buf <- ""
      }
      starts <- seq(1L, nchar(s), by = target)
      out <- c(out, substring(s, starts, starts + target - 1L))
      next
    }
    candidate <- if (nzchar(buf)) paste(buf, s) else s
    if (nzchar(buf) && nchar(candidate) > target) {
      out <- c(out, buf)
      buf <- s
    } else {
      buf <- candidate
    }
  }
  if (nzchar(buf)) {
    out <- c(out, buf)
  }
  out
}

#' @keywords internal
parse_unix_date <- function(raw) {
  if (
    is.null(raw) ||
      identical(raw, "") ||
      identical(raw, 0L) ||
      identical(raw, 0)
  ) {
    return(NULL)
  }
  if (is.numeric(raw)) {
    return(as.integer(raw))
  }
  parsed <- suppressWarnings(as.POSIXct(raw, tz = "UTC"))
  if (is.na(parsed)) {
    parsed <- suppressWarnings(as.POSIXct(
      raw,
      format = "%Y-%m-%dT%H:%M:%S",
      tz = "UTC"
    ))
  }
  if (is.na(parsed)) {
    return(NULL)
  }
  as.integer(unclass(parsed))
}

`%||%` <- function(a, b) if (is.null(a) || identical(a, "")) b else a
