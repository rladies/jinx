html_doc <- function(head) {
  paste0("<html><head>", head, "</head><body><p>Body</p></body></html>")
}

item_of <- function(
  title = "A post",
  link = "https://example.com/a-post"
) {
  data.frame(
    id = link,
    title = title,
    link = link,
    date = 1,
    stringsAsFactors = FALSE
  )
}

source_of <- function(author = "Ariel Muldoon", type = "blog") {
  entry <- list(
    title = "Very Statisticious",
    url = "https://aosmith.rbind.io",
    rss_feed = "https://aosmith.rbind.io/index.xml",
    type = type
  )
  if (!is.null(author)) {
    entry$authors <- list(list(name = author))
  }
  blog_feed_sources(list(entry))$sources
}

block_of <- function(blocks, type) {
  types <- vapply(blocks, function(b) b$type, character(1))
  hit <- which(types == type)
  if (length(hit) == 0L) NULL else blocks[[hit[1L]]]
}

describe("blog_feed_meta", {
  it("reads a property tag, as Open Graph spells it", {
    doc <- xml2::read_html(html_doc(
      '<meta property="og:description" content="From OG">'
    ))
    expect_identical(blog_feed_meta(doc, "og:description"), "From OG")
  })

  it("reads a name tag, as Twitter and plain HTML spell it", {
    doc <- xml2::read_html(html_doc(
      '<meta name="twitter:description" content="From Twitter">'
    ))
    expect_identical(blog_feed_meta(doc, "twitter:description"), "From Twitter")
  })

  it("prefers the earlier name in the list", {
    doc <- xml2::read_html(html_doc(paste0(
      '<meta name="description" content="Plain">',
      '<meta property="og:description" content="OG">'
    )))
    expect_identical(
      blog_feed_meta(doc, c("og:description", "description")),
      "OG"
    )
  })

  it("falls through a tag whose content is empty", {
    doc <- xml2::read_html(html_doc(paste0(
      '<meta property="og:description" content="  ">',
      '<meta name="description" content="Plain">'
    )))
    expect_identical(
      blog_feed_meta(doc, c("og:description", "description")),
      "Plain"
    )
  })

  it("returns an empty string when nothing matches", {
    doc <- xml2::read_html(html_doc("<title>No meta</title>"))
    expect_identical(blog_feed_meta(doc, "og:description"), "")
  })
})

describe("blog_feed_clip", {
  it("collapses whitespace", {
    expect_identical(
      blog_feed_clip("  two   words\n here ", 100L),
      "two words here"
    )
  })

  it("leaves text within the limit alone", {
    expect_identical(blog_feed_clip("short", 100L), "short")
  })

  it("clips on a word boundary and marks the cut", {
    clipped <- blog_feed_clip(strrep("word ", 100L), 20L)
    expect_lt(nchar(clipped), 24L)
    expect_match(clipped, "…$")
    expect_false(grepl("wor…", clipped, fixed = TRUE))
  })

  it("clips mid-word rather than lose most of the text", {
    clipped <- blog_feed_clip(paste0("a ", strrep("b", 60L)), 20L)
    expect_identical(nchar(clipped), 21L)
  })

  it("handles empty and missing input", {
    expect_identical(blog_feed_clip("", 10L), "")
    expect_identical(blog_feed_clip(NULL, 10L), "")
  })
})

describe("blog_feed_safe_image", {
  it("keeps an absolute https image", {
    expect_identical(
      blog_feed_safe_image("https://example.com/hero.png"),
      "https://example.com/hero.png"
    )
  })

  it("resolves a relative image against the post", {
    expect_identical(
      blog_feed_safe_image("/img/hero.png", "https://example.com/posts/one/"),
      "https://example.com/img/hero.png"
    )
  })

  it("refuses a data URI, which Slack cannot fetch", {
    expect_identical(
      blog_feed_safe_image("data:image/png;base64,AAA", "https://example.com/"),
      ""
    )
  })

  it("refuses a javascript: URL", {
    expect_identical(blog_feed_safe_image("javascript:alert(1)"), "")
  })

  it("refuses a URL carrying quotes or whitespace", {
    expect_identical(blog_feed_safe_image('https://e.com/a".png'), "")
    expect_identical(blog_feed_safe_image("https://e.com/a b.png"), "")
  })

  it("returns an empty string for no image", {
    expect_identical(blog_feed_safe_image(""), "")
    expect_identical(blog_feed_safe_image(NULL), "")
  })
})

describe("blog_feed_image_alt", {
  it("uses the author's own image alt when there is one", {
    expect_identical(
      blog_feed_image_alt("A de Bruijn tiling", "Aperiodic tilings"),
      "A de Bruijn tiling"
    )
  })

  it("says what the image is rather than inventing what it shows", {
    expect_identical(
      blog_feed_image_alt("", "Simulating data"),
      "Preview image for “Simulating data”"
    )
  })

  it("never returns an empty alt, since Slack requires one", {
    expect_identical(
      blog_feed_image_alt("", ""),
      "Preview image for this post"
    )
  })
})

describe("blog_feed_og", {
  it("reads description, image and image alt from a page", {
    local_mocked_bindings(
      rag_fetch_text = function(...) {
        html_doc(paste0(
          '<meta property="og:description" content="A post about R">',
          '<meta property="og:image" content="/hero.png">',
          '<meta property="og:image:alt" content="A plot">'
        ))
      }
    )
    og <- blog_feed_og("https://example.com/posts/one/")
    expect_identical(og$description, "A post about R")
    expect_identical(og$image, "https://example.com/hero.png")
    expect_identical(og$image_alt, "A plot")
  })

  it("returns empty fields when the page is unreachable", {
    local_mocked_bindings(rag_fetch_text = function(...) NULL)
    og <- blog_feed_og("https://example.com/posts/one/")
    expect_identical(og$description, "")
    expect_identical(og$image, "")
  })

  it("returns empty fields when the page carries no preview data", {
    local_mocked_bindings(
      rag_fetch_text = function(...) html_doc("<title>Bare</title>")
    )
    expect_identical(blog_feed_og("https://example.com/")$image, "")
  })

  it("survives a fetch that errors", {
    local_mocked_bindings(
      rag_fetch_text = function(...) cli::cli_abort("boom")
    )
    expect_identical(blog_feed_og("https://example.com/")$description, "")
  })
})

describe("blog_feed_blocks", {
  og <- list(
    description = "A post about R",
    image = "https://example.com/hero.png",
    image_alt = "A plot"
  )

  it("puts the heading, linked title and description in one section", {
    section <- block_of(blog_feed_blocks(item_of(), source_of(), og), "section")
    expect_identical(section$text$type, "mrkdwn")
    expect_match(
      section$text$text,
      "New post from an RLadies+ blog",
      fixed = TRUE
    )
    expect_match(
      section$text$text,
      "*<https://example.com/a-post|A post>*",
      fixed = TRUE
    )
    expect_match(section$text$text, "A post about R", fixed = TRUE)
  })

  it("adds the preview image as its own block, with alt and caption", {
    image <- block_of(blog_feed_blocks(item_of(), source_of(), og), "image")
    expect_identical(image$image_url, "https://example.com/hero.png")
    expect_identical(image$alt_text, "A plot")
    expect_identical(image$title$text, "A plot")
    expect_identical(image$title$type, "plain_text")
  })

  it("captions the image only when the author wrote the alt", {
    bare <- og
    bare$image_alt <- ""
    image <- block_of(blog_feed_blocks(item_of(), source_of(), bare), "image")
    expect_null(image$title)
    expect_identical(image$alt_text, "Preview image for “A post”")
  })

  it("omits the image block when there is no usable image", {
    bare <- og
    bare$image <- ""
    expect_null(block_of(
      blog_feed_blocks(item_of(), source_of(), bare),
      "image"
    ))
  })

  it("puts the byline in a context block", {
    context <- block_of(blog_feed_blocks(item_of(), source_of(), og), "context")
    expect_identical(
      context$elements[[1]]$text,
      "by Ariel Muldoon · _Very Statisticious_"
    )
  })

  it("names only the blog when the entry lists no author", {
    blocks <- blog_feed_blocks(item_of(), source_of(author = NULL), og)
    expect_identical(
      block_of(blocks, "context")$elements[[1]]$text,
      "_Very Statisticious_"
    )
  })

  it("works with no preview data at all", {
    blocks <- blog_feed_blocks(item_of(), source_of())
    expect_null(block_of(blocks, "image"))
    expect_match(
      block_of(blocks, "section")$text$text,
      "A post",
      fixed = TRUE
    )
  })

  it("says video for a YouTube source", {
    blocks <- blog_feed_blocks(item_of(), source_of(type = "youtube"), og)
    expect_match(
      block_of(blocks, "section")$text$text,
      "New video from an RLadies+ member",
      fixed = TRUE
    )
  })

  it("neutralises a mass-ping injected through the description", {
    hostile <- og
    hostile$description <- "Read this <!channel>"
    section <- block_of(
      blog_feed_blocks(item_of(), source_of(), hostile),
      "section"
    )
    expect_no_match(section$text$text, "<!channel>", fixed = TRUE)
  })

  it("neutralises markup injected through the title", {
    section <- block_of(
      blog_feed_blocks(
        item_of(title = "Post <https://evil.example|click>"),
        source_of(),
        og
      ),
      "section"
    )
    expect_no_match(
      section$text$text,
      "<https://evil.example|click>",
      fixed = TRUE
    )
  })

  it("serialises as a JSON array of block objects", {
    json <- jsonlite::toJSON(
      blog_feed_blocks(item_of(), source_of(), og),
      auto_unbox = TRUE
    )
    parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    expect_type(parsed, "list")
    expect_identical(parsed[[1]]$type, "section")
    expect_identical(parsed[[2]]$type, "image")
  })
})

describe("blog_feed_block_error", {
  it("treats a blocks or image complaint as worth a plain retry", {
    expect_true(blog_feed_block_error("invalid_blocks"))
    expect_true(blog_feed_block_error("invalid_blocks_format"))
    expect_true(blog_feed_block_error("block_image_download_failed"))
    expect_true(blog_feed_block_error("invalid_arguments"))
  })

  it("leaves an unrelated failure to fail", {
    expect_false(blog_feed_block_error("channel_not_found"))
    expect_false(blog_feed_block_error("not_in_channel"))
    expect_false(blog_feed_block_error("rate_limited"))
    expect_false(blog_feed_block_error(""))
    expect_false(blog_feed_block_error(NULL))
  })
})

describe("blog_feed_send", {
  post <- list(item = item_of(), source = source_of())

  it("sends blocks and turns off unfurl when there is a preview", {
    sent <- NULL
    local_mocked_bindings(
      blog_feed_og = function(...) {
        list(description = "D", image = "https://e.com/i.png", image_alt = "")
      },
      slack_post_message = function(
        text,
        channel,
        token,
        unfurl,
        blocks = NULL
      ) {
        sent <<- list(unfurl = unfurl, blocks = blocks, text = text)
        list(ok = TRUE)
      }
    )
    blog_feed_send("fallback", post, "blogs", "xoxb-test")
    expect_false(sent$unfurl)
    expect_identical(sent$text, "fallback")
    expect_identical(sent$blocks[[1]]$type, "section")
  })

  it("lets Slack unfurl when the post offers no preview", {
    sent <- NULL
    local_mocked_bindings(
      blog_feed_og = function(...) {
        list(description = "", image = "", image_alt = "")
      },
      slack_post_message = function(
        text,
        channel,
        token,
        unfurl,
        blocks = NULL
      ) {
        sent <<- list(unfurl = unfurl, blocks = blocks)
        list(ok = TRUE)
      }
    )
    blog_feed_send("fallback", post, "blogs", "xoxb-test")
    expect_true(sent$unfurl)
    expect_null(sent$blocks)
  })

  it("retries as plain text when Slack refuses the blocks", {
    calls <- list()
    local_mocked_bindings(
      blog_feed_og = function(...) {
        list(description = "D", image = "https://e.com/i.png", image_alt = "")
      },
      slack_post_message = function(
        text,
        channel,
        token,
        unfurl,
        blocks = NULL
      ) {
        calls[[length(calls) + 1L]] <<- list(blocks = blocks, unfurl = unfurl)
        if (!is.null(blocks)) {
          return(list(ok = FALSE, error = "invalid_blocks"))
        }
        list(ok = TRUE)
      }
    )
    expect_message(
      resp <- blog_feed_send("fallback", post, "blogs", "xoxb-test"),
      "refused the preview"
    )
    expect_true(resp$ok)
    expect_length(calls, 2L)
    expect_null(calls[[2]]$blocks)
    expect_true(calls[[2]]$unfurl)
  })

  it("does not retry a failure that is not about the blocks", {
    calls <- 0L
    local_mocked_bindings(
      blog_feed_og = function(...) {
        list(description = "D", image = "", image_alt = "")
      },
      slack_post_message = function(...) {
        calls <<- calls + 1L
        list(ok = FALSE, error = "channel_not_found")
      }
    )
    resp <- blog_feed_send("fallback", post, "blogs", "xoxb-test")
    expect_false(resp$ok)
    expect_equal(calls, 1L)
  })
})

describe("blog_feed_og_memo", {
  it("reads a post's page once however often it is asked", {
    reads <- 0L
    memo <- blog_feed_og_memo(function(url) {
      reads <<- reads + 1L
      list(description = url, image = "", image_alt = "")
    })
    first <- memo("https://example.com/a")
    second <- memo("https://example.com/a")
    expect_equal(reads, 1L)
    expect_identical(first, second)
  })

  it("reads each distinct post", {
    reads <- character()
    memo <- blog_feed_og_memo(function(url) {
      reads <<- c(reads, url)
      list(description = url, image = "", image_alt = "")
    })
    memo("https://example.com/a")
    memo("https://example.com/b")
    memo("https://example.com/a")
    expect_identical(reads, c("https://example.com/a", "https://example.com/b"))
  })

  it("keeps nothing between runs", {
    reads <- 0L
    fetch <- function(url) {
      reads <<- reads + 1L
      list(description = "", image = "", image_alt = "")
    }
    blog_feed_og_memo(fetch)("https://example.com/a")
    blog_feed_og_memo(fetch)("https://example.com/a")
    expect_equal(reads, 2L)
  })
})
