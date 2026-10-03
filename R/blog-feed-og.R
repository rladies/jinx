#' Meta tags read for each piece of preview data, in order of preference
#'
#' Open Graph first, then Twitter's equivalents, then the plain
#' description - the community's blogs are built by half a dozen site
#' generators and set whichever of these their theme happens to support.
#'
#' @return A named list of character vectors of meta tag names.
#' @keywords internal
#' @noRd
blog_feed_meta_names <- function() {
  list(
    description = c("og:description", "twitter:description", "description"),
    image = c("og:image", "og:image:url", "twitter:image", "twitter:image:src"),
    image_alt = c("og:image:alt", "twitter:image:alt")
  )
}

#' Longest description to carry into Slack
#'
#' Enough for a couple of lines under the title. Slack's own limit is far
#' higher, but a post's whole first paragraph in a feed channel buries the
#' next post rather than helping anyone decide to click.
#'
#' @return Integer scalar.
#' @keywords internal
#' @noRd
blog_feed_description_chars <- function() 300L

#' Read a post's Open Graph preview data
#'
#' One extra request per *new* post - not per feed, and not per item - so
#' at a post a week this is nothing next to polling the feeds themselves.
#' Every failure returns empty: a post with no preview is still worth
#' announcing, so nothing here is allowed to abort the run.
#'
#' @param url The post's URL.
#' @return A list with `description`, `image`, and `image_alt`, each a
#'   character scalar that may be `""`.
#' @export
blog_feed_og <- function(url) {
  empty <- list(description = "", image = "", image_alt = "")
  html <- tryCatch(
    rag_fetch_text(rag_request(url)),
    error = function(e) NULL
  )
  if (is.null(html)) {
    return(empty)
  }
  doc <- tryCatch(xml2::read_html(html), error = function(e) NULL)
  if (is.null(doc)) {
    return(empty)
  }

  names <- blog_feed_meta_names()
  list(
    description = blog_feed_clip(
      blog_feed_meta(doc, names$description),
      blog_feed_description_chars()
    ),
    image = blog_feed_safe_image(blog_feed_meta(doc, names$image), url),
    image_alt = blog_feed_clip(blog_feed_meta(doc, names$image_alt), 1000L)
  )
}

#' Read the first of several meta tags that carries a value
#'
#' Matches `property` (Open Graph's spelling) and `name` (Twitter's and
#' HTML's) alike, because themes disagree about which to use even for the
#' `og:` tags.
#'
#' @param doc Parsed HTML document.
#' @param names Meta tag names to try, most preferred first.
#' @return The tag's content, or `""` when none of them carries one.
#' @keywords internal
#' @noRd
blog_feed_meta <- function(doc, names) {
  for (name in names) {
    quoted <- paste0("\"", name, "\"")
    node <- xml2::xml_find_first(
      doc,
      paste0("//meta[@property=", quoted, " or @name=", quoted, "]")
    )
    if (inherits(node, "xml_missing")) {
      next
    }
    content <- xml2::xml_attr(node, "content")
    if (!is.na(content) && nzchar(trimws(content))) {
      return(trimws(content))
    }
  }
  ""
}

#' Collapse whitespace and clip to a length, on a word boundary
#'
#' @param text Raw meta tag content.
#' @param max_chars Longest result, before the ellipsis.
#' @return The clipped text, or `""`.
#' @keywords internal
#' @noRd
blog_feed_clip <- function(text, max_chars) {
  s <- trimws(gsub("\\s+", " ", text %||% ""))
  if (!nzchar(s) || nchar(s) <= max_chars) {
    return(s)
  }
  cut <- substr(s, 1L, max_chars)
  spaced <- regmatches(cut, regexpr("^.*\\s", cut))
  stem <- if (length(spaced) == 1L && nchar(spaced) > max_chars * 0.6) {
    spaced
  } else {
    cut
  }
  paste0(trimws(stem), "\u2026")
}

#' Accept a preview image only if Slack can be asked to fetch it
#'
#' Slack fetches `image_url` server-side and rejects the whole message if
#' it cannot - so a bad `og:image` would otherwise cost us the post, not
#' just the picture. Relative URLs are resolved against the post, and
#' anything that is not then a plain http(s) URL is dropped.
#'
#' @param image Raw `og:image` content.
#' @param base The post's URL, to resolve a relative image against.
#' @return The image URL, or `""`.
#' @keywords internal
#' @noRd
blog_feed_safe_image <- function(image, base = NULL) {
  s <- trimws(image %||% "")
  if (!nzchar(s)) {
    return("")
  }
  if (!is_blank(base) && !grepl("^[a-zA-Z][a-zA-Z0-9+.-]*:", s)) {
    s <- tryCatch(xml2::url_absolute(s, base), error = function(e) s)
  }
  if (!grepl("^https?://[^\\s<>\"']+$", s, perl = TRUE)) {
    return("")
  }
  s
}

#' Describe a preview image for a screen reader
#'
#' Slack requires `alt_text` on an image block. No blog in the curated
#' list sets `og:image:alt`, so when one is missing this says what the
#' image *is* rather than inventing what it shows - we have not seen it,
#' and a confident fabricated description is worse than none.
#'
#' @param image_alt The post's `og:image:alt`, possibly `""`.
#' @param title The post's title.
#' @return A character scalar, never empty.
#' @keywords internal
#' @noRd
blog_feed_image_alt <- function(image_alt, title) {
  if (nzchar(image_alt %||% "")) {
    return(image_alt)
  }
  clipped <- blog_feed_clip(title, 200L)
  if (nzchar(clipped)) {
    glue::glue("Preview image for \u201c{clipped}\u201d")
  } else {
    "Preview image for this post"
  }
}

#' Read preview data at most once per post per run
#'
#' Both workspaces announce the same posts, so without this the page is
#' fetched once per workspace - the same waste that polling the feeds per
#' workspace would be. The cache lives for one run only: a post's preview
#' is read when it is first announced and never looked at again.
#'
#' @param fetch The underlying reader, for tests.
#' @return A function of one argument (the post URL) returning the same
#'   list as [blog_feed_og()].
#' @keywords internal
#' @noRd
blog_feed_og_memo <- function(fetch = blog_feed_og) {
  cache <- new.env(parent = emptyenv())
  function(url) {
    key <- as.character(url)
    if (!is.null(cache[[key]])) {
      return(cache[[key]])
    }
    value <- fetch(url)
    cache[[key]] <- value
    value
  }
}
