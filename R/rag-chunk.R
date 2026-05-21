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
  date <- meta$date %||% parse_unix_date(parts$frontmatter$date) %||% 0L
  lastmod <- meta$lastmod %||%
    parse_unix_date(parts$frontmatter$lastmod) %||%
    date
  title <- parts$frontmatter$title %||% meta$fallback_title %||% ""

  per_section <- lapply(sections, function(section) {
    pieces <- trimws(split_to_target(section$body, target_chars))
    pieces <- pieces[nchar(pieces) >= min_chars]
    lapply(pieces, function(text) {
      list(
        text = text,
        heading = section$heading,
        title = title,
        repo = meta$repo,
        path = meta$path,
        url = meta$url,
        date = date,
        lastmod = lastmod
      )
    })
  })
  unlist(per_section, recursive = FALSE)
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
  if (!length(lines)) {
    return(list())
  }
  is_heading <- grepl("^#{1,2}\\s+", lines)
  group <- cumsum(is_heading)
  by_group <- split(seq_along(lines), group)
  sections <- lapply(seq_along(by_group), function(gi) {
    idx <- by_group[[gi]]
    g <- as.integer(names(by_group)[gi])
    if (g == 0L) {
      heading <- ""
      body_lines <- lines[idx]
    } else {
      heading <- trimws(sub("^#{1,2}\\s+", "", lines[idx[1]]))
      body_lines <- lines[idx[-1]]
    }
    list(
      heading = heading,
      body = paste0(paste(body_lines, collapse = "\n"), "\n")
    )
  })
  Filter(function(s) nzchar(trimws(s$body)), sections)
}

#' @keywords internal
split_to_target <- function(text, target) {
  if (nchar(text) <= target) {
    return(text)
  }
  paragraphs <- strsplit(text, "\n\\s*\n", perl = TRUE)[[1]]
  pack_pieces(paragraphs, target, sep = "\n\n", hard = hard_split)
}

#' @keywords internal
hard_split <- function(text, target) {
  sentences <- strsplit(text, "(?<=[.!?])\\s+", perl = TRUE)[[1]]
  pack_pieces(sentences, target, sep = " ", hard = chunk_chars)
}

#' @keywords internal
chunk_chars <- function(text, target) {
  starts <- seq(1L, nchar(text), by = target)
  substring(text, starts, starts + target - 1L)
}

#' @keywords internal
pack_pieces <- function(pieces, target, sep, hard) {
  out <- character()
  buf <- ""
  for (p in pieces) {
    if (nchar(p) > target) {
      if (nzchar(buf)) {
        out <- c(out, buf)
        buf <- ""
      }
      out <- c(out, hard(p, target))
      next
    }
    candidate <- if (nzchar(buf)) paste0(buf, sep, p) else p
    if (nzchar(buf) && nchar(candidate) > target) {
      out <- c(out, buf)
      buf <- p
    } else {
      buf <- candidate
    }
  }
  if (nzchar(buf)) c(out, buf) else out
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
