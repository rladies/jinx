#' URL of the aggregated awesome-creations content list
#'
#' The blog feed is driven by the same curated list the website reads, so
#' adding a blog to `awesome-rladies-creations` is all it takes to get its
#' posts into Slack. Overridable with `AWESOME_CONTENT_URL` for testing
#' against a fork or branch.
#'
#' @return Character scalar URL.
#' @keywords internal
#' @noRd
blog_feed_content_url <- function() {
  env_default(
    "AWESOME_CONTENT_URL",
    paste0(
      "https://raw.githubusercontent.com/rladies/",
      "awesome-rladies-creations/main/data/website/awesome_content.json"
    )
  )
}

blog_feed_seen_key <- function(workspace) {
  glue::glue("blog_feed_seen:{workspace}")
}

#' How many item ids to remember per workspace
#'
#' The seen-set is what stops a post being announced twice, so it has to
#' outlive every feed's own window: a feed that serves 20 items and
#' publishes weekly is remembered for months at this size, while the value
#' stays small enough for a single KV read.
#'
#' @return Integer scalar.
#' @keywords internal
#' @noRd
blog_feed_memory <- function() 2000L

#' Load the curated content list
#'
#' @param url Aggregated JSON URL.
#' @return A list of entry records, empty if the fetch or parse failed.
#' @keywords internal
#' @noRd
blog_feed_entries <- function(url = blog_feed_content_url()) {
  entries <- rag_fetch_json(rag_request(url))
  if (!is.list(entries) || length(entries) == 0L) {
    cli::cli_warn("blog-feed: no content entries at {url}")
    return(list())
  }
  entries
}

#' Split curated entries into pollable sources and gaps
#'
#' An entry is pollable when it carries an `rss_feed`, whatever its `type`
#' - YouTube channels and plain websites serve the same Atom/RSS XML as
#' blogs do. Entries without a feed can't be polled at all, so they are
#' returned separately for the run to report rather than dropped silently.
#'
#' @param entries List of entry records from the curated content list.
#' @return A list with `sources` (a data frame with columns `title`,
#'   `site`, `feed`, `author`, and `type`) and `feedless` (a character
#'   vector of titles).
#' @export
blog_feed_sources <- function(entries) {
  empty <- data.frame(
    title = character(),
    site = character(),
    feed = character(),
    author = character(),
    type = character(),
    stringsAsFactors = FALSE
  )
  if (!is.list(entries) || length(entries) == 0L) {
    return(list(sources = empty, feedless = character()))
  }

  rows <- lapply(entries, blog_feed_source_row)
  sources <- do.call(rbind, Filter(Negate(is.null), rows)) %||% empty
  feedless <- vapply(entries, blog_feed_feedless_title, character(1))

  list(sources = sources, feedless = feedless[nzchar(feedless)])
}

blog_feed_source_row <- function(entry) {
  if (is_blank(entry$rss_feed) || is_blank(entry$url)) {
    return(NULL)
  }
  site <- normalise_awesome_url(entry$url)
  data.frame(
    title = entry$title %or% site,
    site = site,
    feed = normalise_awesome_url(entry$rss_feed),
    author = format_authors(entry$authors),
    type = entry$type %or% "content",
    stringsAsFactors = FALSE
  )
}

blog_feed_feedless_title <- function(entry) {
  if (!is_blank(entry$rss_feed)) {
    return("")
  }
  as.character(entry$title %or% entry$url %or% "")
}

blog_feed_empty_items <- function() {
  data.frame(
    id = character(),
    title = character(),
    link = character(),
    date = numeric(),
    stringsAsFactors = FALSE
  )
}

#' Parse an RSS or Atom document into a data frame of items
#'
#' Matched on `local-name()` rather than a namespace prefix: the feeds in
#' the curated list are a mix of RSS 2.0, Atom, and RSS 1.0/RDF written by
#' half a dozen site generators, and only the element names are reliably
#' shared between them.
#'
#' @param xml Feed document as text.
#' @param base Feed URL, used to resolve relative item links.
#' @param max_items Keep at most this many items from the top of the feed.
#' @return A data frame with columns `id`, `title`, `link`, and `date` (a
#'   unix timestamp, `0` when the feed gave no usable date).
#' @export
blog_feed_items <- function(xml, base = NULL, max_items = 25L) {
  doc <- if (is_blank(xml)) {
    NULL
  } else {
    tryCatch(xml2::read_xml(xml), error = function(e) NULL)
  }
  if (is.null(doc)) {
    return(blog_feed_empty_items())
  }

  nodes <- xml2::xml_find_all(
    doc,
    "//*[local-name()='item' or local-name()='entry']"
  )
  if (length(nodes) == 0L) {
    return(blog_feed_empty_items())
  }
  nodes <- nodes[seq_len(min(length(nodes), max_items))]

  rows <- Filter(
    Negate(is.null),
    lapply(nodes, blog_feed_item_row, base = base)
  )
  if (length(rows) == 0L) {
    return(blog_feed_empty_items())
  }
  do.call(rbind, rows)
}

blog_feed_item_row <- function(node, base = NULL) {
  link <- blog_feed_safe_link(blog_feed_item_link(node), base)
  if (!nzchar(link)) {
    return(NULL)
  }
  title <- blog_feed_child_text(node, "title")
  data.frame(
    id = blog_feed_item_id(node, link),
    title = if (nzchar(title)) title else link,
    link = link,
    date = blog_feed_item_date(node),
    stringsAsFactors = FALSE
  )
}

blog_feed_child_text <- function(node, name) {
  found <- xml2::xml_find_first(
    node,
    glue::glue("./*[local-name()='{name}']")
  )
  if (inherits(found, "xml_missing")) {
    return("")
  }
  trimws(gsub("\\s+", " ", xml2::xml_text(found)))
}

#' Pull an item's permalink out of either feed dialect
#'
#' RSS puts the URL in `<link>`'s text; Atom puts it in a `<link>`
#' element's `href`, which leaves that element's text empty. Atom feeds
#' also carry several links (`self`, `replies`, `enclosure`), so prefer the
#' one marked `rel="alternate"` - the human-readable page - before falling
#' back to the first href present.
#'
#' @param node One `item`/`entry` node.
#' @return The permalink, or `""` when the item has none.
#' @keywords internal
#' @noRd
blog_feed_item_link <- function(node) {
  text_link <- blog_feed_child_text(node, "link")
  if (nzchar(text_link)) {
    return(text_link)
  }

  links <- xml2::xml_find_all(node, "./*[local-name()='link']")
  if (length(links) == 0L) {
    return("")
  }
  hrefs <- trimws(xml2::xml_attr(links, "href"))
  rels <- xml2::xml_attr(links, "rel")
  usable <- !is.na(hrefs) & nzchar(hrefs)
  if (!any(usable)) {
    return("")
  }
  alternate <- usable & (is.na(rels) | rels == "alternate")
  if (any(alternate)) {
    return(hrefs[which(alternate)[1L]])
  }
  hrefs[which(usable)[1L]]
}

#' Resolve an item link and accept it only if it is safe to link to
#'
#' Hugo and Quarto sites built without an absolute `baseURL` emit relative
#' item links (`/post/2019-01-23-rstudio-conf/`), so the link is resolved
#' against the feed's own URL before it is checked - a sizeable slice of
#' the curated list would otherwise go unannounced.
#'
#' What survives that has to be a plain http(s) URL. The URL goes into
#' `<url|label>` unescaped - escaping it would break the link - so a feed
#' could otherwise close the markup early with `|` or `>` and append its
#' own text, or hand members a `javascript:` target.
#'
#' @param link Candidate URL from the feed.
#' @param base Feed URL to resolve a relative link against.
#' @return The URL, or `""` when it is not safe to link.
#' @keywords internal
#' @noRd
blog_feed_safe_link <- function(link, base = NULL) {
  if (
    nzchar(link) && !is_blank(base) && !grepl("^[a-zA-Z][a-zA-Z0-9+.-]*:", link)
  ) {
    link <- tryCatch(
      xml2::url_absolute(link, base),
      error = function(e) link
    )
  }
  if (!grepl("^https?://[^\\s<>|\"\']+$", link, perl = TRUE)) {
    if (nzchar(link)) {
      cli::cli_alert_warning("blog-feed: skipping unusable link {link}")
    }
    return("")
  }
  link
}

blog_feed_item_id <- function(node, link) {
  for (name in c("guid", "id")) {
    id <- blog_feed_child_text(node, name)
    if (nzchar(id)) {
      return(id)
    }
  }
  link
}

#' Read an item's publication date as a unix timestamp
#'
#' Tries the RSS, Atom, and Dublin Core date elements in turn. RSS 2.0
#' dates are RFC 822 (`Tue, 30 Sep 2025 10:00:00 +0000`), which
#' `as.POSIXct()` cannot read, so those formats are tried explicitly
#' before handing anything left to the ISO 8601 parser.
#'
#' @param node One `item`/`entry` node.
#' @return A unix timestamp, or `0` when no element parsed.
#' @keywords internal
#' @noRd
blog_feed_item_date <- function(node) {
  for (name in c("pubDate", "published", "updated", "date", "modified")) {
    raw <- blog_feed_child_text(node, name)
    if (!nzchar(raw)) {
      next
    }
    parsed <- blog_feed_parse_date(raw)
    if (parsed > 0) {
      return(parsed)
    }
  }
  0
}

#' Parse a feed date string into a unix timestamp
#'
#' Feeds carry dates in at least three dialects: RSS 2.0's RFC 822
#' (`Tue, 30 Sep 2025 10:00:00 +0000`), Atom's RFC 3339
#' (`2025-09-30T10:00:00+02:00`), and RSS 1.0's bare date. `as.POSIXct()`
#' reads none of them reliably - given an RFC 3339 string its default
#' formats fall through to the date-only one and silently return midnight -
#' so the zone is taken off the end and the remainder matched against each
#' dialect explicitly.
#'
#' @param raw The raw date string.
#' @return A unix timestamp, or `0` when nothing parsed.
#' @keywords internal
#' @noRd
blog_feed_parse_date <- function(raw) {
  offset <- blog_feed_utc_offset(raw)
  stamp <- blog_feed_strip_zone(raw)
  formats <- c(
    "%a, %d %b %Y %H:%M:%S",
    "%d %b %Y %H:%M:%S",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d"
  )
  for (fmt in formats) {
    parsed <- tryCatch(
      suppressWarnings(as.POSIXct(stamp, format = fmt, tz = "UTC")),
      error = function(e) NA
    )
    if (!is.na(parsed)) {
      return(as.numeric(parsed) - offset)
    }
  }
  0
}

#' Seconds to subtract to bring a feed date back to UTC
#'
#' The formats above stop before the zone, so `as.POSIXct()` would read
#' `+0200` as if it were UTC and the timestamp would land two hours late.
#' Named zones other than `GMT`/`UT`/`UTC`/`Z` are rare in feeds and
#' ambiguous by design, so they are treated as UTC.
#'
#' @param raw The raw date string.
#' @return Offset in seconds, `0` when the string carries no numeric zone.
#' @keywords internal
#' @noRd
blog_feed_utc_offset <- function(raw) {
  m <- regmatches(raw, regexpr("[+-][0-9]{2}:?[0-9]{2}\\s*$", raw))
  if (length(m) == 0L || !nzchar(m)) {
    return(0)
  }
  digits <- gsub("[^0-9]", "", m)
  sign <- if (grepl("^-", trimws(m))) -1 else 1
  hours <- as.numeric(substr(digits, 1L, 2L))
  minutes <- as.numeric(substr(digits, 3L, 4L))
  sign * (hours * 3600 + minutes * 60)
}

#' Strip a trailing time zone, named or numeric, off a feed date
#'
#' @param raw The raw date string.
#' @return The date string without its zone suffix.
#' @keywords internal
#' @noRd
blog_feed_strip_zone <- function(raw) {
  trimws(gsub(
    "([+-][0-9]{2}:?[0-9]{2}|Z|GMT|UTC?|[A-Z]{3})\\s*$",
    "",
    trimws(raw)
  ))
}

#' Fetch and parse one source's feed
#'
#' @param feed Feed URL.
#' @param max_items Passed to [blog_feed_items()].
#' @return A data frame of items, empty when the feed was unreachable or
#'   unparseable.
#' @keywords internal
#' @noRd
blog_feed_fetch <- function(feed, max_items = 25L) {
  xml <- rag_fetch_text(rag_request(feed))
  if (is.null(xml)) {
    cli::cli_alert_warning("blog-feed: could not read {feed}")
    return(blog_feed_empty_items())
  }
  items <- blog_feed_items(xml, base = feed, max_items = max_items)
  if (nrow(items) == 0L) {
    cli::cli_alert_warning("blog-feed: no items parsed from {feed}")
  }
  items
}

#' Keep the items worth announcing
#'
#' Drops anything already announced and anything older than `max_age_days`
#' - a blog joining the curated list arrives with its whole back
#' catalogue in the feed, and without the age gate its first run would
#' announce years of posts at once. Items with no usable date are treated
#' as too old for the same reason.
#'
#' @param items Data frame from [blog_feed_items()].
#' @param seen Character vector of item ids already announced.
#' @param max_age_days Only announce items published within this window.
#' @param now Current time, as a unix timestamp.
#' @return A subset of `items`, oldest first.
#' @export
blog_feed_new_items <- function(
  items,
  seen = character(),
  max_age_days = 14,
  now = as.numeric(Sys.time())
) {
  if (is.null(items) || nrow(items) == 0L) {
    return(blog_feed_empty_items())
  }
  fresh <- items$date > 0 & (now - items$date) <= max_age_days * 86400
  keep <- fresh & !items$id %in% seen
  new <- items[keep, , drop = FALSE]
  new[order(new$date), , drop = FALSE]
}

#' Format one new post as a Slack mrkdwn message
#'
#' Titles and author names come from feeds and curated JSON that
#' contributors control, so both are escaped before they go into a
#' broadcast message - that neutralises injected links and
#' `<!channel>`/`<!everyone>` mass-pings while leaving the message's own
#' link markup intact.
#'
#' @param item A one-row data frame from [blog_feed_items()].
#' @param source A one-row data frame from [blog_feed_sources()].
#' @return Character scalar Slack mrkdwn message.
#' @export
blog_feed_format <- function(item, source) {
  heading <- blog_feed_heading(source$type)
  byline <- if (nzchar(source$author)) {
    glue::glue("by {escape_markdown(source$author)} \u00b7 ")
  } else {
    ""
  }
  glue::glue(
    "{heading}\n",
    "<{item$link}|{escape_markdown(item$title)}>\n",
    "{byline}_{escape_markdown(source$title)}_"
  )
}

blog_feed_heading <- function(type) {
  switch(
    as.character(type),
    youtube = "\U0001F4FD\uFE0F *New video from an RLadies+ member*",
    "\U0001F4DD *New post from an RLadies+ blog*"
  )
}

blog_feed_seen_load <- function(
  workspace,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  kv_string_set_load(
    blog_feed_seen_key(workspace),
    namespace_id,
    account_id,
    api_token
  )
}

blog_feed_seen_save <- function(
  workspace,
  seen,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  kv_string_set_save(
    blog_feed_seen_key(workspace),
    seen,
    keep = blog_feed_memory(),
    namespace_id = namespace_id,
    account_id = account_id,
    api_token = api_token
  )
}

#' Collect every new post across the curated feeds
#'
#' Polls each source in turn, keeping going when an individual feed is
#' down so one dead blog can't silence the rest, then returns the new
#' items sorted oldest first so the channel reads in publication order.
#'
#' @param seen Character vector of item ids already announced.
#' @inheritParams blog_feed_new_items
#' @param entries Curated content entries. Fetched when `NULL`.
#' @param limit Maximum number of posts to return in one run.
#' @return A list with `posts` (a list of `item`/`source` pairs),
#'   `feedless` (titles with no `rss_feed`), and `sources` (how many feeds
#'   were polled).
#' @export
blog_feed_collect <- function(
  seen = character(),
  entries = NULL,
  max_age_days = 14,
  limit = 20L,
  now = as.numeric(Sys.time())
) {
  split <- blog_feed_sources(entries %||% blog_feed_entries())
  sources <- split$sources
  posts <- list()

  for (i in seq_len(nrow(sources))) {
    source <- sources[i, , drop = FALSE]
    items <- blog_feed_fetch(source$feed)
    new <- blog_feed_new_items(items, seen, max_age_days, now)
    for (j in seq_len(nrow(new))) {
      posts[[length(posts) + 1L]] <- list(
        item = new[j, , drop = FALSE],
        source = source
      )
    }
  }

  order_by_date <- order(vapply(posts, function(p) p$item$date, numeric(1)))
  posts <- blog_feed_distinct(posts[order_by_date])
  if (length(posts) > limit) {
    cli::cli_alert_warning(
      "blog-feed: {length(posts)} new posts, announcing the {limit} oldest"
    )
    posts <- posts[seq_len(limit)]
  }

  list(posts = posts, feedless = split$feedless, sources = nrow(sources))
}

#' Drop a post the same run has already collected from another feed
#'
#' Two curated entries can resolve to the same post - a blog listed with
#' both its main feed and a category feed, or a site that moved and is
#' listed twice - and `seen` is only consulted at the start of a run, so
#' nothing else would stop the channel getting the item twice.
#'
#' @param posts List of `item`/`source` pairs, oldest first.
#' @return The same list with later duplicates of an item id removed.
#' @keywords internal
#' @noRd
blog_feed_distinct <- function(posts) {
  if (length(posts) == 0L) {
    return(posts)
  }
  ids <- vapply(posts, function(p) p$item$id, character(1))
  posts[!duplicated(ids)]
}

#' Announce new community posts in a workspace's blog channel
#'
#' Replaces the Slack Feed app's per-blog subscriptions with one run
#' driven by `awesome-rladies-creations`: a blog added to the curated list
#' is announced in both workspaces without anyone touching Slack.
#'
#' Announced ids are recorded in KV per workspace, and only after a
#' successful post - a failed run re-announces nothing and loses nothing.
#'
#' @param workspace Which Slack workspace to post in.
#' @param channel Channel to post to. Defaults to env
#'   `SLACK_BLOG_CHANNEL`, falling back to `"blogs-by-rladies"`.
#' @param dry_run When `TRUE`, print the messages and record nothing.
#' @param seed When `TRUE`, record every current feed item as announced
#'   without posting. Run once per workspace at cutover so the first real
#'   run doesn't repeat what the Feed app already posted.
#' @param slack_token Bot token for `workspace`.
#' @inheritParams blog_feed_collect
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return Invisibly, the number of posts announced.
#' @export
blog_feed_post <- function(
  workspace = c("community", "organiser"),
  channel = env_default("SLACK_BLOG_CHANNEL", "blogs-by-rladies"),
  dry_run = FALSE,
  seed = FALSE,
  slack_token = NULL,
  entries = NULL,
  max_age_days = 14,
  limit = 20L,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  workspace <- match.arg(workspace)
  entries <- entries %||% blog_feed_entries()

  if (seed) {
    return(invisible(blog_feed_seed(
      workspace,
      entries,
      namespace_id,
      account_id,
      api_token,
      dry_run = dry_run
    )))
  }

  seen <- blog_feed_seen_load(
    workspace,
    namespace_id,
    account_id,
    api_token
  )
  collected <- blog_feed_collect(
    seen = seen,
    entries = entries,
    max_age_days = max_age_days,
    limit = limit
  )
  blog_feed_report_feedless(collected$feedless)

  if (length(collected$posts) == 0L) {
    cli::cli_alert_info(
      "No new community posts across {collected$sources} feed{?s}."
    )
    return(invisible(0L))
  }

  if (!dry_run && is_blank(slack_token)) {
    slack_token <- slack_bot_token(workspace)
  }
  announced <- character()
  for (post in collected$posts) {
    text <- blog_feed_format(post$item, post$source)
    if (dry_run) {
      cli::cli_alert_info("Would post to #{channel}:\n{text}")
      next
    }
    resp <- slack_post_message(
      text,
      channel = channel,
      token = slack_token,
      unfurl = TRUE
    )
    if (!isTRUE(resp$ok)) {
      cli::cli_abort(
        paste0(
          "Failed to post to #{channel}: {resp$error %||% 'unknown error'}. ",
          "Announced {length(announced)} post{?s} before failing."
        )
      )
    }
    announced <- c(announced, post$item$id)
  }

  if (dry_run) {
    cli::cli_alert_info(
      "Dry run: {length(collected$posts)} post{?s} would go to #{channel}."
    )
    return(invisible(length(collected$posts)))
  }

  blog_feed_seen_save(
    workspace,
    c(seen, announced),
    namespace_id,
    account_id,
    api_token
  )
  cli::cli_alert_success(
    "Announced {length(announced)} post{?s} in #{channel} ({workspace})"
  )
  invisible(length(announced))
}

#' Record every current feed item as announced, without posting
#'
#' @inheritParams blog_feed_post
#' @return The number of ids recorded.
#' @keywords internal
#' @noRd
blog_feed_seed <- function(
  workspace,
  entries,
  namespace_id,
  account_id,
  api_token,
  dry_run = FALSE
) {
  split <- blog_feed_sources(entries)
  ids <- unlist(lapply(
    split$sources$feed,
    function(feed) blog_feed_fetch(feed)$id
  ))
  ids <- unique(as.character(ids))
  if (dry_run) {
    cli::cli_alert_info(
      "Dry run: {length(ids)} item{?s} would be seeded for {workspace}."
    )
    return(length(ids))
  }
  blog_feed_seen_save(workspace, ids, namespace_id, account_id, api_token)
  cli::cli_alert_success(
    "Seeded {length(ids)} item{?s} as announced for {workspace}."
  )
  length(ids)
}

blog_feed_report_feedless <- function(feedless) {
  if (length(feedless) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_alert_warning(
    paste0(
      "blog-feed: {length(feedless)} curated entr{?y/ies} have no ",
      "{.field rss_feed} and cannot be announced: ",
      "{.val {feedless}}"
    )
  )
  invisible(NULL)
}
