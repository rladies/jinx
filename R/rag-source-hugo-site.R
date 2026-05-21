HUGO_SITE_MIN_CHARS <- 200L
HUGO_SKIP_PATH_PATTERNS <- c("^/directory/[^/]+/?$")

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
#' @return List of chunk records.
#' @keywords internal
gather_hugo_site <- function(src) {
  cli::cli_alert_info("Crawling {src$repo} via {src$sitemap}")
  urls <- collect_sitemap_urls(src$sitemap)
  cli::cli_alert_info("  {length(urls)} URLs from sitemap")

  filtered <- Filter(
    function(u) is_english_url(u, src) && !is_skipped_url(u),
    urls
  )
  cli::cli_alert_info("  {length(filtered)} to crawl after filters")

  out <- list()
  fetch_failed <- 0L
  no_article <- 0L
  too_short <- 0L
  for (i in seq_along(filtered)) {
    url <- filtered[[i]]
    html <- rag_fetch_text(url)
    if (is.null(html)) {
      fetch_failed <- fetch_failed + 1L
      next
    }
    page <- extract_hugo_page(html, normalise_hugo_url(url), src)
    if (is.null(page)) {
      no_article <- no_article + 1L
      next
    }
    if (nchar(page$markdown) < HUGO_SITE_MIN_CHARS) {
      too_short <- too_short + 1L
      next
    }
    chunks <- chunk_markdown(
      page$markdown,
      meta = list(
        repo = src$repo,
        path = url_path(page$url),
        url = page$url,
        fallback_title = page$title,
        date = page$date,
        lastmod = page$lastmod
      )
    )
    for (k in seq_along(chunks)) {
      chunks[[k]]$chunk_idx <- k - 1L
      out[[length(out) + 1L]] <- chunks[[k]]
    }
    if (i %% 100L == 0L) {
      cli::cli_alert_info("  ...{i}/{length(filtered)}")
    }
  }
  cli::cli_alert_info(
    "  {length(out)} chunks (fetch-fail {fetch_failed}, no main/article {no_article}, thin {too_short})"
  )
  out
}

collect_sitemap_urls <- function(url, depth = 0L) {
  if (depth > 2L) {
    return(character())
  }
  xml <- rag_fetch_text(url)
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
  out <- character()
  for (child in locs) {
    out <- c(out, collect_sitemap_urls(child, depth + 1L))
  }
  out
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

  drop_selectors <- c(
    "script",
    "style",
    "noscript",
    "nav",
    "footer",
    "aside",
    "form",
    "button"
  )
  for (sel in drop_selectors) {
    xml2::xml_remove(rvest::html_elements(article, sel))
  }

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
  html_str <- as.character(node)
  in_file <- tempfile(fileext = ".html")
  out_file <- tempfile(fileext = ".md")
  on.exit(unlink(c(in_file, out_file)), add = TRUE)
  writeLines(html_str, in_file, useBytes = TRUE)
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
  parsed <- httr2::url_parse(url)
  parts <- strsplit(parsed$path %||% "/", "/", fixed = TRUE)[[1]]
  first <- parts[nzchar(parts)][1]
  if (is.na(first) || is.null(first)) {
    return(TRUE)
  }
  english <- src$language_roots$english
  if (!is.null(english) && nzchar(english) && identical(first, english)) {
    return(TRUE)
  }
  others <- src$language_roots$others %||% list()
  !(first %in% unlist(others))
}

is_skipped_url <- function(url) {
  path <- httr2::url_parse(url)$path %||% "/"
  any(vapply(
    HUGO_SKIP_PATH_PATTERNS,
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
