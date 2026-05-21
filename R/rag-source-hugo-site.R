#' Gather chunks from a Hugo site by crawling its sitemap
#'
#' Walks the sitemap (and any nested sitemap-index), filters out
#' non-English language roots and configured skip patterns, fetches
#' each page, extracts the `<main>` or `<article>` body, converts it
#' to GitHub-flavoured markdown via pandoc, and runs the result
#' through `chunk_markdown()`. Required `src` fields: `repo`,
#' `sitemap`. Optional: `title_suffix`, `language_roots`.
#'
#' @param src Source spec list.
#' @param min_chars Drop pages whose extracted markdown is shorter
#'   than this many characters.
#' @param skip_path_patterns Perl-compatible regex patterns; URLs
#'   whose path matches any of them are skipped.
#' @param progress_every Log a progress line every N URLs.
#' @return List of chunk records.
#' @keywords internal
gather_hugo_site <- function(
  src,
  min_chars = src$min_chars %||% 200L,
  skip_path_patterns = src$skip_path_patterns %||% c("^/directory/[^/]+/?$"),
  progress_every = src$progress_every %||% 100L
) {
  cli::cli_alert_info("Crawling {src$repo} via {src$sitemap}")
  urls <- collect_sitemap_urls(src$sitemap)
  cli::cli_alert_info("  {length(urls)} URLs from sitemap")

  keep <- vapply(urls, is_english_url, logical(1), src = src) &
    !vapply(urls, is_skipped_url, logical(1), patterns = skip_path_patterns)
  filtered <- urls[keep]
  cli::cli_alert_info("  {length(filtered)} to crawl after filters")

  per_url <- lapply(
    seq_along(filtered),
    function(i) {
      hugo_url_chunks(
        filtered[[i]],
        i,
        length(filtered),
        src,
        min_chars = min_chars,
        progress_every = progress_every
      )
    }
  )
  chunks <- unlist(Filter(Negate(is.null), per_url), recursive = FALSE) %||%
    list()
  cli::cli_alert_info("  {length(chunks)} chunks total")
  chunks
}

hugo_url_chunks <- function(url, i, total, src, min_chars, progress_every) {
  if (i %% progress_every == 0L) {
    cli::cli_alert_info("  ...{i}/{total}")
  }
  html <- rag_fetch_text(rag_request(url))
  if (is.null(html)) {
    return(NULL)
  }
  page <- extract_hugo_page(html, normalise_hugo_url(url), src)
  if (is.null(page) || nchar(page$markdown) < min_chars) {
    return(NULL)
  }
  assign_chunk_idx(chunk_markdown(
    page$markdown,
    meta = list(
      repo = src$repo,
      path = url_path(page$url),
      url = page$url,
      fallback_title = page$title,
      date = page$date,
      lastmod = page$lastmod
    )
  ))
}

collect_sitemap_urls <- function(url, depth = 0L, max_depth = 2L) {
  if (depth > max_depth) {
    return(character())
  }
  xml <- rag_fetch_text(rag_request(url))
  if (is.null(xml)) {
    return(character())
  }
  doc <- tryCatch(xml2::read_xml(xml), error = function(e) NULL)
  if (is.null(doc)) {
    return(character())
  }
  ns <- xml2::xml_ns_rename(xml2::xml_ns(doc), d1 = "sm")
  is_index <- length(xml2::xml_find_all(doc, "//sm:sitemapindex", ns)) > 0L ||
    grepl("<sitemapindex", xml, fixed = TRUE)
  locs <- xml2::xml_text(xml2::xml_find_all(doc, "//sm:loc", ns))
  if (length(locs) == 0L) {
    locs <- xml2::xml_text(xml2::xml_find_all(doc, "//loc"))
  }
  locs <- trimws(locs)
  if (!is_index) {
    return(locs)
  }
  unlist(lapply(
    locs,
    collect_sitemap_urls,
    depth = depth + 1L,
    max_depth = max_depth
  ))
}

extract_hugo_page <- function(html, url, src) {
  doc <- tryCatch(
    rvest::read_html(html, encoding = "UTF-8"),
    error = function(e) NULL
  )
  if (is.null(doc)) {
    return(NULL)
  }
  title <- rvest::html_text2(rvest::html_element(doc, "title"))
  title <- strip_suffix(trimws(title %||% ""), src$title_suffix %||% "")
  description <- trimws(
    rvest::html_attr(
      rvest::html_element(doc, "meta[name='description']"),
      "content"
    ) %||%
      ""
  )
  published <- rag_parse_date(
    rvest::html_attr(
      rvest::html_element(doc, "meta[property='article:published_time']"),
      "content"
    )
  )
  modified <- rag_parse_date(
    rvest::html_attr(
      rvest::html_element(doc, "meta[property='article:modified_time']"),
      "content"
    )
  )
  date <- if (published > 0L) published else modified
  lastmod <- if (modified > 0L) modified else published

  article <- rvest::html_element(doc, "main")
  if (is.na(article)) {
    article <- rvest::html_element(doc, "article")
  }
  if (is.na(article)) {
    return(NULL)
  }

  xml2::xml_remove(rvest::html_elements(
    article,
    "script, style, noscript, nav, footer, aside, form, button"
  ))

  markdown <- html_node_to_markdown(article)
  if (nzchar(description)) {
    markdown <- paste0(description, "\n\n", markdown)
  }
  if (nzchar(title) && !startsWith(markdown, paste0("# ", title))) {
    markdown <- paste0("# ", title, "\n\n", markdown)
  }
  list(
    url = url,
    title = title,
    description = description,
    date = date,
    lastmod = lastmod,
    markdown = trimws(markdown)
  )
}

html_node_to_markdown <- function(node) {
  in_file <- tempfile(fileext = ".html")
  out_file <- tempfile(fileext = ".md")
  on.exit(unlink(c(in_file, out_file)), add = TRUE)
  writeLines(as.character(node), in_file, useBytes = TRUE)
  tryCatch(
    rmarkdown::pandoc_convert(
      input = in_file,
      from = "html",
      to = "gfm-raw_html",
      output = out_file,
      options = c("--wrap=none")
    ),
    error = function(e) {
      cli::cli_warn("pandoc html->md failed: {conditionMessage(e)}")
      writeLines(rvest::html_text2(node), out_file, useBytes = TRUE)
    }
  )
  paste(readLines(out_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

is_english_url <- function(url, src) {
  parts <- strsplit(httr2::url_parse(url)$path %||% "/", "/", fixed = TRUE)[[1]]
  first <- parts[nzchar(parts)][1]
  if (is.na(first) || is.null(first)) {
    return(TRUE)
  }
  english <- src$language_roots$english
  if (!is.null(english) && nzchar(english) && identical(first, english)) {
    return(TRUE)
  }
  !(first %in% unlist(src$language_roots$others %||% list()))
}

is_skipped_url <- function(url, patterns) {
  path <- httr2::url_parse(url)$path %||% "/"
  any(vapply(
    patterns,
    function(p) grepl(p, path, perl = TRUE),
    logical(1)
  ))
}

normalise_hugo_url <- function(url) sub("/index\\.html$", "/", url)

url_path <- function(url) httr2::url_parse(url)$path %||% "/"

strip_suffix <- function(s, suffix) {
  if (!nzchar(suffix)) {
    return(s)
  }
  if (endsWith(s, suffix)) {
    trimws(substr(s, 1L, nchar(s) - nchar(suffix)))
  } else {
    s
  }
}
