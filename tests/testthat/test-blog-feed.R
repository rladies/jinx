rss_doc <- function(items) {
  paste0(
    "<?xml version='1.0'?><rss version='2.0'><channel>",
    paste(items, collapse = ""),
    "</channel></rss>"
  )
}

rss_item <- function(
  title = "A post",
  link = "https://example.com/a-post",
  guid = "https://example.com/a-post",
  date = "Tue, 30 Sep 2025 10:00:00 +0000"
) {
  glue::glue(
    "<item><title>{title}</title><link>{link}</link>",
    "<guid>{guid}</guid><pubDate>{date}</pubDate></item>"
  )
}

atom_doc <- function(entries) {
  paste0(
    "<?xml version='1.0'?><feed xmlns='http://www.w3.org/2005/Atom'>",
    paste(entries, collapse = ""),
    "</feed>"
  )
}

content_entry <- function(
  title = "Very Statisticious",
  url = "https://aosmith.rbind.io",
  rss_feed = "https://aosmith.rbind.io/index.xml",
  type = "blog",
  author = "Ariel Muldoon"
) {
  entry <- list(title = title, url = url, type = type)
  if (!is.null(rss_feed)) {
    entry$rss_feed <- rss_feed
  }
  if (!is.null(author)) {
    entry$authors <- list(list(name = author))
  }
  entry
}

describe("blog_feed_sources", {
  it("keeps entries with a feed and names those without one", {
    split <- blog_feed_sources(list(
      content_entry(),
      content_entry(
        title = "Florencia D'Andrea",
        url = "https://florenciadandrea.com",
        rss_feed = NULL,
        type = "website"
      )
    ))
    expect_equal(nrow(split$sources), 1L)
    expect_identical(split$sources$title, "Very Statisticious")
    expect_identical(split$feedless, "Florencia D'Andrea")
  })

  it("polls a YouTube channel like any other source", {
    split <- blog_feed_sources(list(content_entry(
      title = "ggnot2's channel",
      url = "https://www.youtube.com/c/ggnot2",
      rss_feed = "https://www.youtube.com/feeds/videos.xml?channel_id=UC1",
      type = "youtube"
    )))
    expect_equal(nrow(split$sources), 1L)
    expect_identical(split$sources$type, "youtube")
  })

  it("makes a bare host absolute", {
    split <- blog_feed_sources(list(content_entry(
      url = "amanda.rbind.io",
      rss_feed = "amanda.rbind.io/index.xml"
    )))
    expect_identical(split$sources$site, "https://amanda.rbind.io")
    expect_identical(split$sources$feed, "https://amanda.rbind.io/index.xml")
  })

  it("collapses several authors into one byline", {
    entry <- content_entry(author = NULL)
    entry$authors <- list(list(name = "Mine"), list(name = "Rob"))
    split <- blog_feed_sources(list(entry))
    expect_identical(split$sources$author, "Mine, Rob")
  })

  it("returns empty results for no entries", {
    split <- blog_feed_sources(list())
    expect_equal(nrow(split$sources), 0L)
    expect_length(split$feedless, 0L)
  })
})

describe("blog_feed_items", {
  it("parses an RSS item", {
    items <- blog_feed_items(rss_doc(rss_item()))
    expect_equal(nrow(items), 1L)
    expect_identical(items$title, "A post")
    expect_identical(items$link, "https://example.com/a-post")
    expect_gt(items$date, 0)
  })

  it("parses an Atom entry, preferring the alternate link", {
    items <- blog_feed_items(atom_doc(paste0(
      "<entry><title>Atom post</title>",
      "<link rel='self' href='https://example.com/feed'/>",
      "<link rel='alternate' href='https://example.com/atom-post'/>",
      "<id>tag:example.com,2025:1</id>",
      "<published>2025-09-30T10:00:00Z</published></entry>"
    )))
    expect_identical(items$link, "https://example.com/atom-post")
    expect_identical(items$id, "tag:example.com,2025:1")
  })

  it("falls back to the first href when no link is marked alternate", {
    items <- blog_feed_items(atom_doc(paste0(
      "<entry><title>T</title>",
      "<link rel='enclosure' href='https://example.com/first'/>",
      "<published>2025-09-30T10:00:00Z</published></entry>"
    )))
    expect_identical(items$link, "https://example.com/first")
  })

  it("falls back to the link as id when the item has no guid", {
    items <- blog_feed_items(rss_doc(
      "<item><title>T</title><link>https://example.com/p</link></item>"
    ))
    expect_identical(items$id, "https://example.com/p")
  })

  it("uses the link as title when the item has none", {
    items <- blog_feed_items(rss_doc(
      "<item><link>https://example.com/p</link></item>"
    ))
    expect_identical(items$title, "https://example.com/p")
  })

  it("resolves a root-relative link against the feed URL", {
    items <- blog_feed_items(
      rss_doc(rss_item(link = "/post/2019-rstudio-conf/")),
      base = "https://sctyner.me/category/r/index.xml"
    )
    expect_identical(items$link, "https://sctyner.me/post/2019-rstudio-conf/")
  })

  it("resolves a path-relative link against the feed URL", {
    items <- blog_feed_items(
      rss_doc(rss_item(link = "2019-rstudio-conf/")),
      base = "https://sctyner.me/category/r/index.xml"
    )
    expect_identical(
      items$link,
      "https://sctyner.me/category/r/2019-rstudio-conf/"
    )
  })

  it("drops a relative link when there is no feed URL to resolve it", {
    expect_message(
      items <- blog_feed_items(rss_doc(rss_item(link = "/post/p/"))),
      "unusable link"
    )
    expect_equal(nrow(items), 0L)
  })

  it("leaves an absolute link alone when a base is given", {
    items <- blog_feed_items(
      rss_doc(rss_item(link = "https://example.com/a-post")),
      base = "https://other.example/index.xml"
    )
    expect_identical(items$link, "https://example.com/a-post")
  })

  it("still refuses a javascript: link when a base is given", {
    expect_message(
      items <- blog_feed_items(
        rss_doc(rss_item(link = "javascript:alert(1)")),
        base = "https://example.com/index.xml"
      ),
      "unusable link"
    )
    expect_equal(nrow(items), 0L)
  })

  it("drops an item with no link at all", {
    items <- blog_feed_items(rss_doc("<item><title>Linkless</title></item>"))
    expect_equal(nrow(items), 0L)
  })

  it("drops an item whose link could break out of the Slack markup", {
    expect_message(
      items <- blog_feed_items(rss_doc(rss_item(
        link = "https://example.com/p|evil>text"
      ))),
      "unusable link"
    )
    expect_equal(nrow(items), 0L)
  })

  it("drops a javascript: link", {
    expect_message(
      items <- blog_feed_items(rss_doc(rss_item(
        link = "javascript:alert(1)"
      ))),
      "unusable link"
    )
    expect_equal(nrow(items), 0L)
  })

  it("collapses whitespace in a wrapped title", {
    items <- blog_feed_items(rss_doc(rss_item(
      title = "A  post\n  over lines"
    )))
    expect_identical(items$title, "A post over lines")
  })

  it("keeps at most max_items from the top of the feed", {
    items <- blog_feed_items(
      rss_doc(c(
        rss_item(guid = "a", link = "https://example.com/a"),
        rss_item(guid = "b", link = "https://example.com/b"),
        rss_item(guid = "c", link = "https://example.com/c")
      )),
      max_items = 2L
    )
    expect_identical(items$id, c("a", "b"))
  })

  it("returns no items for a feed with none", {
    expect_equal(nrow(blog_feed_items(rss_doc(character()))), 0L)
  })

  it("returns no items for unparseable or empty input", {
    expect_equal(nrow(blog_feed_items("<not xml")), 0L)
    expect_equal(nrow(blog_feed_items("")), 0L)
    expect_equal(nrow(blog_feed_items(NULL)), 0L)
  })
})

describe("blog_feed_item_date", {
  parse_one <- function(item) blog_feed_items(rss_doc(item))$date

  it("reads an RFC 822 date", {
    expect_equal(
      parse_one(rss_item(date = "Tue, 30 Sep 2025 10:00:00 +0000")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("applies a positive UTC offset", {
    expect_equal(
      parse_one(rss_item(date = "Tue, 30 Sep 2025 12:00:00 +0200")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("applies a negative UTC offset", {
    expect_equal(
      parse_one(rss_item(date = "Tue, 30 Sep 2025 06:30:00 -0330")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("reads an RFC 822 date without a weekday", {
    expect_equal(
      parse_one(rss_item(date = "30 Sep 2025 10:00:00 GMT")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("reads an RFC 3339 date with a colon in the offset", {
    expect_equal(
      parse_one(rss_item(date = "2025-09-30T12:00:00+02:00")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("reads a bare date", {
    expect_equal(
      parse_one(rss_item(date = "2025-09-30")),
      as.numeric(as.POSIXct("2025-09-30 00:00:00", tz = "UTC"))
    )
  })

  it("reads an ISO 8601 date", {
    expect_equal(
      parse_one(rss_item(date = "2025-09-30T10:00:00Z")),
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("falls back to updated when there is no pubDate", {
    items <- blog_feed_items(atom_doc(paste0(
      "<entry><title>T</title>",
      "<link rel='alternate' href='https://example.com/p'/>",
      "<updated>2025-09-30T10:00:00Z</updated></entry>"
    )))
    expect_equal(
      items$date,
      as.numeric(as.POSIXct("2025-09-30 10:00:00", tz = "UTC"))
    )
  })

  it("reports no date for an unparseable one", {
    expect_equal(parse_one(rss_item(date = "last Thursday")), 0)
  })
})

describe("blog_feed_new_items", {
  now <- as.numeric(as.POSIXct("2025-10-01 00:00:00", tz = "UTC"))
  items <- data.frame(
    id = c("new", "old", "seen"),
    title = c("New", "Old", "Seen"),
    link = sprintf("https://example.com/%s", c("new", "old", "seen")),
    date = c(now - 86400, now - 86400 * 60, now - 3600),
    stringsAsFactors = FALSE
  )

  it("keeps a recent unseen item", {
    new <- blog_feed_new_items(items, seen = "seen", now = now)
    expect_identical(new$id, "new")
  })

  it("drops an item older than the age window", {
    new <- blog_feed_new_items(items, max_age_days = 90, now = now)
    expect_true("old" %in% new$id)
    expect_false("old" %in% blog_feed_new_items(items, now = now)$id)
  })

  it("drops an item with no usable date", {
    dated <- items
    dated$date <- 0
    expect_equal(nrow(blog_feed_new_items(dated, now = now)), 0L)
  })

  it("returns items oldest first", {
    new <- blog_feed_new_items(items, now = now)
    expect_identical(new$id, c("new", "seen"))
  })

  it("handles an empty feed", {
    expect_equal(nrow(blog_feed_new_items(blog_feed_items(""))), 0L)
    expect_equal(nrow(blog_feed_new_items(NULL)), 0L)
  })
})

describe("blog_feed_format", {
  split <- blog_feed_sources(list(content_entry()))
  item <- blog_feed_items(rss_doc(rss_item()))

  it("links the post and credits the author and blog", {
    md <- blog_feed_format(item, split$sources)
    expect_match(md, "New post from an RLadies+ blog", fixed = TRUE)
    expect_match(md, "<https://example.com/a-post|A post>", fixed = TRUE)
    expect_match(md, "by Ariel Muldoon", fixed = TRUE)
    expect_match(md, "_Very Statisticious_", fixed = TRUE)
  })

  it("says video for a YouTube source", {
    yt <- blog_feed_sources(list(content_entry(
      type = "youtube",
      rss_feed = "https://www.youtube.com/feeds/videos.xml?channel_id=UC1"
    )))
    expect_match(
      blog_feed_format(item, yt$sources),
      "New video from an RLadies+ member",
      fixed = TRUE
    )
  })

  it("omits the byline when the entry lists no author", {
    anon <- blog_feed_sources(list(content_entry(author = NULL)))
    expect_no_match(blog_feed_format(item, anon$sources), "by ", fixed = TRUE)
  })

  it("neutralises a mass-ping injected through a post title", {
    hostile <- blog_feed_items(rss_doc(rss_item(
      title = "Hello &lt;!channel&gt; everyone"
    )))
    md <- blog_feed_format(hostile, split$sources)
    expect_no_match(md, "<!channel>", fixed = TRUE)
    expect_match(md, "&lt;!channel&gt;", fixed = TRUE)
  })

  it("neutralises markup injected through a curated blog title", {
    hostile <- blog_feed_sources(list(content_entry(
      title = "Blog <https://evil.example|click me>"
    )))
    md <- blog_feed_format(item, hostile$sources)
    expect_no_match(md, "<https://evil.example|click me>", fixed = TRUE)
  })
})

describe("blog_feed_collect", {
  entries <- list(
    content_entry(),
    content_entry(
      title = "Second blog",
      url = "https://second.example",
      rss_feed = "https://second.example/index.xml"
    ),
    content_entry(
      title = "No feed",
      url = "https://none.example",
      rss_feed = NULL
    )
  )
  now <- as.numeric(as.POSIXct("2025-10-01 00:00:00", tz = "UTC"))

  feeds <- function(map) {
    function(req, ...) map[[req$url]] %||% rss_doc(character())
  }

  it("collects recent posts from every source, oldest first", {
    local_mocked_bindings(
      rag_fetch_text = feeds(list(
        "https://aosmith.rbind.io/index.xml" = rss_doc(rss_item(
          guid = "first",
          link = "https://example.com/first",
          date = "Mon, 29 Sep 2025 10:00:00 +0000"
        )),
        "https://second.example/index.xml" = rss_doc(rss_item(
          guid = "second",
          link = "https://example.com/second",
          date = "Tue, 30 Sep 2025 10:00:00 +0000"
        ))
      ))
    )
    collected <- blog_feed_collect(entries = entries, now = now)
    expect_identical(
      vapply(collected$posts, function(p) p$item$id, character(1)),
      c("first", "second")
    )
    expect_identical(collected$feedless, "No feed")
    expect_equal(collected$sources, 2L)
  })

  it("carries each post's source alongside it", {
    local_mocked_bindings(
      rag_fetch_text = feeds(list(
        "https://second.example/index.xml" = rss_doc(rss_item(guid = "s"))
      ))
    )
    collected <- blog_feed_collect(entries = entries, now = now)
    expect_identical(collected$posts[[1]]$source$title, "Second blog")
  })

  it("collects a post once when two feeds carry it", {
    local_mocked_bindings(
      rag_fetch_text = feeds(list(
        "https://aosmith.rbind.io/index.xml" = rss_doc(rss_item(guid = "same")),
        "https://second.example/index.xml" = rss_doc(rss_item(guid = "same"))
      ))
    )
    collected <- blog_feed_collect(entries = entries, now = now)
    expect_length(collected$posts, 1L)
  })

  it("keeps polling when one feed is unreachable", {
    local_mocked_bindings(
      rag_fetch_text = function(req, ...) {
        if (grepl("aosmith", req$url)) {
          return(NULL)
        }
        rss_doc(rss_item(guid = "survivor"))
      }
    )
    expect_message(
      collected <- blog_feed_collect(entries = entries, now = now),
      "could not read"
    )
    expect_identical(collected$posts[[1]]$item$id, "survivor")
  })

  it("warns about a feed it cannot parse", {
    local_mocked_bindings(rag_fetch_text = function(...) "<not a feed/>")
    expect_message(
      blog_feed_collect(entries = entries, now = now),
      "no items parsed"
    )
  })

  it("does not filter by what any workspace has announced", {
    local_mocked_bindings(
      rag_fetch_text = feeds(list(
        "https://aosmith.rbind.io/index.xml" = rss_doc(rss_item(guid = "old")),
        "https://second.example/index.xml" = rss_doc(rss_item(guid = "old"))
      )),
      blog_feed_seen_load = function(...) "old"
    )
    expect_length(blog_feed_collect(entries = entries, now = now)$posts, 1L)
  })
})

describe("blog_feed_pending", {
  posts <- lapply(c("a", "b", "c"), function(id) {
    list(item = data.frame(id = id, date = 1, stringsAsFactors = FALSE))
  })

  it("drops what this workspace has already announced", {
    pending <- blog_feed_pending(posts, seen = c("a", "c"))
    expect_identical(
      vapply(pending, function(p) p$item$id, character(1)),
      "b"
    )
  })

  it("caps a run at limit posts, keeping the oldest", {
    expect_message(
      pending <- blog_feed_pending(posts, limit = 2L),
      "announcing the 2 oldest"
    )
    expect_identical(
      vapply(pending, function(p) p$item$id, character(1)),
      c("a", "b")
    )
  })

  it("returns nothing when everything has been announced", {
    expect_length(blog_feed_pending(posts, seen = c("a", "b", "c")), 0L)
  })

  it("handles an empty collection", {
    expect_length(blog_feed_pending(list()), 0L)
  })
})

describe("blog_feed_seen_load", {
  it("reads a stored id list", {
    local_mocked_bindings(cf_ops_get_kv_value = function(...) '["a","b"]')
    expect_identical(blog_feed_seen_load("community"), c("a", "b"))
  })

  it("starts empty when the key is unset", {
    local_mocked_bindings(cf_ops_get_kv_value = function(...) "")
    expect_identical(blog_feed_seen_load("community"), character())
  })

  it("starts empty when the stored value is not JSON", {
    local_mocked_bindings(cf_ops_get_kv_value = function(...) "{not json")
    expect_identical(blog_feed_seen_load("community"), character())
  })

  it("starts empty when the KV read errors", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) cli::cli_abort("boom")
    )
    expect_identical(blog_feed_seen_load("community"), character())
  })
})

describe("blog_feed_seen_save", {
  it("stores the most recent ids under the workspace's key", {
    captured <- NULL
    local_mocked_bindings(
      cf_ops_kv_put = function(..., key_name, value) {
        captured <<- list(key = key_name, value = value)
      }
    )
    blog_feed_seen_save("organiser", c("a", "b"))
    expect_identical(captured$key, "blog_feed_seen:organiser")
    expect_identical(
      as.character(jsonlite::fromJSON(captured$value)),
      c("a", "b")
    )
  })

  it("drops duplicates and forgets beyond the memory limit", {
    captured <- NULL
    local_mocked_bindings(
      cf_ops_kv_put = function(..., key_name, value) captured <<- value
    )
    ids <- c("dup", "dup", sprintf("id%04d", seq_len(blog_feed_memory())))
    blog_feed_seen_save("community", ids)
    stored <- as.character(jsonlite::fromJSON(captured))
    expect_length(stored, blog_feed_memory())
    expect_false("dup" %in% stored)
  })
})

describe("blog_feed_post", {
  entries <- list(content_entry())
  one_post <- function(env = parent.frame()) {
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(rss_item(guid = "p1")),
      blog_feed_seen_load = function(...) character(),
      .env = env
    )
  }

  it("posts each new item and records it as announced", {
    posted <- list()
    saved <- NULL
    one_post()
    local_mocked_bindings(
      slack_post_message = function(text, channel, ...) {
        posted[[length(posted) + 1L]] <<- list(text = text, channel = channel)
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(workspace, seen, ...) saved <<- seen
    )
    count <- blog_feed_post(
      "community",
      channel = "blogs-by-rladies",
      slack_token = "xoxb-test",
      entries = entries,
      max_age_days = 1e6
    )
    expect_equal(count, 1L)
    expect_length(posted, 1L)
    expect_identical(posted[[1]]$channel, "blogs-by-rladies")
    expect_identical(saved, "p1")
  })

  it("announces posts it is handed rather than polling again", {
    collected_posts <- list(list(
      item = blog_feed_items(rss_doc(rss_item(guid = "handed"))),
      source = blog_feed_sources(entries)$sources
    ))
    local_mocked_bindings(
      rag_fetch_text = function(...) cli::cli_abort("should not poll"),
      blog_feed_seen_load = function(...) character(),
      slack_post_message = function(...) list(ok = TRUE),
      blog_feed_seen_save = function(...) NULL
    )
    expect_equal(
      blog_feed_post(
        "community",
        posts = collected_posts,
        slack_token = "xoxb-test"
      ),
      1L
    )
  })

  it("lets Slack unfurl the post so the channel shows previews", {
    unfurled <- NULL
    one_post()
    local_mocked_bindings(
      slack_post_message = function(text, channel, token, unfurl = FALSE) {
        unfurled <<- unfurl
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    blog_feed_post(
      "community",
      slack_token = "xoxb-test",
      entries = entries,
      max_age_days = 1e6
    )
    expect_true(unfurled)
  })

  it("records nothing and posts nothing on a dry run", {
    one_post()
    local_mocked_bindings(
      slack_post_message = function(...) cli::cli_abort("should not post"),
      blog_feed_seen_save = function(...) cli::cli_abort("should not save")
    )
    expect_message(
      count <- blog_feed_post(
        "community",
        dry_run = TRUE,
        slack_token = "xoxb-test",
        entries = entries,
        max_age_days = 1e6
      ),
      "Would post"
    )
    expect_equal(count, 1L)
  })

  it("needs no Slack token for a dry run", {
    one_post()
    local_mocked_bindings(
      slack_bot_token = function(...) cli::cli_abort("should not need a token"),
      slack_post_message = function(...) cli::cli_abort("should not post")
    )
    expect_message(
      blog_feed_post(
        "community",
        dry_run = TRUE,
        entries = entries,
        max_age_days = 1e6
      ),
      "Would post"
    )
  })

  it("falls back to the workspace token when none is passed", {
    one_post()
    local_mocked_bindings(
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        expect_identical(token, "xoxb-organiser")
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    blog_feed_post("organiser", entries = entries, max_age_days = 1e6)
  })

  it("treats an empty token as unset rather than posting with it", {
    one_post()
    local_mocked_bindings(
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        expect_identical(token, "xoxb-community")
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    blog_feed_post(
      "community",
      slack_token = "",
      entries = entries,
      max_age_days = 1e6
    )
  })

  it("keeps what it managed to announce before a post failed", {
    saved <- NULL
    posts <- lapply(c("ok", "fails"), function(id) {
      list(
        item = blog_feed_items(rss_doc(rss_item(
          guid = id,
          link = paste0("https://example.com/", id)
        ))),
        source = blog_feed_sources(entries)$sources
      )
    })
    local_mocked_bindings(
      blog_feed_seen_load = function(...) character(),
      slack_post_message = function(text, ...) {
        if (grepl("fails", text, fixed = TRUE)) {
          return(list(ok = FALSE, error = "rate_limited"))
        }
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(workspace, seen, ...) saved <<- seen
    )
    expect_error(
      blog_feed_post("community", posts = posts, slack_token = "xoxb-test"),
      "rate_limited"
    )
    expect_identical(saved, "ok")
  })

  it("reports nothing to do when no feed has new items", {
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(character()),
      blog_feed_seen_load = function(...) character(),
      slack_post_message = function(...) cli::cli_abort("should not post")
    )
    expect_message(
      count <- blog_feed_post(
        "community",
        slack_token = "xoxb-test",
        entries = entries
      ),
      "Nothing new"
    )
    expect_equal(count, 0L)
  })

  it("names curated entries that cannot be announced", {
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(character()),
      blog_feed_seen_load = function(...) character()
    )
    expect_message(
      blog_feed_post(
        "community",
        slack_token = "xoxb-test",
        entries = list(content_entry(rss_feed = NULL))
      ),
      "No feed|no .*rss_feed"
    )
  })

  it("rejects an unknown workspace", {
    expect_error(blog_feed_post("slack-hq"), "should be one of")
  })

  it("defaults the channel to blogs-by-rladies", {
    withr::with_envvar(c(SLACK_BLOG_CHANNEL = ""), {
      expect_equal(eval(formals(blog_feed_post)$channel), "blogs-by-rladies")
    })
  })

  it("honours an explicitly set channel", {
    withr::with_envvar(c(SLACK_BLOG_CHANNEL = "blog-test"), {
      expect_equal(eval(formals(blog_feed_post)$channel), "blog-test")
    })
  })
})

describe("blog_feed_run", {
  entries <- list(content_entry())

  it("polls the feeds once and announces in every workspace", {
    polls <- 0L
    posted <- character()
    local_mocked_bindings(
      rag_fetch_text = function(...) {
        polls <<- polls + 1L
        rss_doc(rss_item(guid = "p1"))
      },
      blog_feed_seen_load = function(workspace, ...) character(),
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        posted <<- c(posted, token)
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    counts <- blog_feed_run(entries = entries, max_age_days = 1e6)
    expect_equal(polls, 1L)
    expect_identical(posted, c("xoxb-community", "xoxb-organiser"))
    expect_equal(unname(counts), c(1L, 1L))
  })

  it("respects each workspace's own seen-set", {
    posted <- character()
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(rss_item(guid = "p1")),
      blog_feed_seen_load = function(workspace, ...) {
        if (identical(workspace, "community")) "p1" else character()
      },
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        posted <<- c(posted, token)
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    expect_message(
      counts <- blog_feed_run(entries = entries, max_age_days = 1e6),
      "Nothing new"
    )
    expect_identical(posted, "xoxb-organiser")
    expect_equal(counts[["community"]], 0L)
  })

  it("still announces in the other workspace when one fails", {
    posted <- character()
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(rss_item(guid = "p1")),
      blog_feed_seen_load = function(...) character(),
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        if (identical(token, "xoxb-community")) {
          return(list(ok = FALSE, error = "channel_not_found"))
        }
        posted <<- c(posted, token)
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    expect_error(
      expect_message(
        blog_feed_run(entries = entries, max_age_days = 1e6),
        "channel_not_found"
      ),
      "failed for"
    )
    expect_identical(posted, "xoxb-organiser")
  })

  it("seeds every workspace from one poll, without posting", {
    seeded <- character()
    polls <- 0L
    local_mocked_bindings(
      rag_fetch_text = function(...) {
        polls <<- polls + 1L
        rss_doc(rss_item(guid = "a"))
      },
      slack_post_message = function(...) cli::cli_abort("should not post"),
      blog_feed_seen_save = function(workspace, seen, ...) {
        seeded <<- c(seeded, workspace)
      }
    )
    expect_message(
      blog_feed_run(seed = TRUE, entries = entries),
      "Seeded 1 item"
    )
    expect_equal(polls, 1L)
    expect_identical(seeded, c("community", "organiser"))
  })

  it("records nothing when seeding on a dry run", {
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(rss_item(guid = "a")),
      slack_post_message = function(...) cli::cli_abort("should not post"),
      blog_feed_seen_save = function(...) cli::cli_abort("should not save")
    )
    expect_message(
      blog_feed_run(seed = TRUE, dry_run = TRUE, entries = entries),
      "would be seeded"
    )
  })

  it("can be pointed at a single workspace", {
    posted <- character()
    local_mocked_bindings(
      rag_fetch_text = function(...) rss_doc(rss_item(guid = "p1")),
      blog_feed_seen_load = function(...) character(),
      slack_bot_token = function(workspace) paste0("xoxb-", workspace),
      slack_post_message = function(text, channel, token, ...) {
        posted <<- c(posted, token)
        list(ok = TRUE)
      },
      blog_feed_seen_save = function(...) NULL
    )
    blog_feed_run("organiser", entries = entries, max_age_days = 1e6)
    expect_identical(posted, "xoxb-organiser")
  })
})

describe("blog_feed_entries", {
  it("warns and returns nothing when the list is unreachable", {
    local_mocked_bindings(rag_fetch_json = function(...) NULL)
    expect_warning(entries <- blog_feed_entries("https://x.example/c.json"))
    expect_length(entries, 0L)
  })

  it("passes the parsed list through", {
    local_mocked_bindings(
      rag_fetch_json = function(...) list(content_entry())
    )
    expect_length(blog_feed_entries(), 1L)
  })

  it("reads the rladies list by default", {
    withr::with_envvar(c(AWESOME_CONTENT_URL = ""), {
      expect_match(blog_feed_content_url(), "awesome-rladies-creations")
    })
  })

  it("can be pointed at another copy of the list", {
    withr::with_envvar(c(AWESOME_CONTENT_URL = "https://x.example/c.json"), {
      expect_identical(blog_feed_content_url(), "https://x.example/c.json")
    })
  })
})
