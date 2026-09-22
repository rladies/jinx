describe("chapter_meta_render / chapter_meta_parse", {
  it("round-trips the chapter details", {
    block <- chapter_meta_render(
      "Oslo",
      "Norway",
      organizers = c("A", "B")
    )
    meta <- chapter_meta_parse(paste("Some prose.\n\n", block))
    expect_identical(meta$city, "Oslo")
    expect_identical(meta$country, "Norway")
    expect_identical(meta$organizers, c("A", "B"))
    expect_null(meta$region)
  })

  it("round-trips a region when there is one", {
    block <- chapter_meta_render("La Plata", "Argentina", "Buenos Aires", "A")
    expect_identical(chapter_meta_parse(block)$region, "Buenos Aires")
  })

  it("keeps a single organiser as a character vector", {
    block <- chapter_meta_render("Oslo", "Norway", organizers = "Solo")
    expect_identical(chapter_meta_parse(block)$organizers, "Solo")
  })

  it("survives a chapter with no organisers yet", {
    block <- chapter_meta_render("Oslo", "Norway")
    expect_identical(chapter_meta_parse(block)$organizers, character(0))
  })

  it("hides the block from the rendered issue text", {
    block <- chapter_meta_render("Oslo", "Norway")
    expect_true(startsWith(block, "<!--"))
    expect_true(endsWith(block, "-->"))
  })

  it("never records organiser email addresses", {
    block <- chapter_meta_render("Oslo", "Norway", organizers = "A")
    expect_false(grepl("email", block, ignore.case = TRUE))
  })
})

describe("chapter_meta_parse", {
  it("returns NULL for an issue with no block", {
    expect_null(chapter_meta_parse("Just prose about a chapter."))
    expect_null(chapter_meta_parse(""))
    expect_null(chapter_meta_parse(NULL))
  })

  it("warns and returns NULL on an unreadable block", {
    broken <- "<!-- jinx:chapter\n{not json at all\n-->"
    expect_message(meta <- chapter_meta_parse(broken))
    expect_null(meta)
  })

  it("reads the block even when prose follows it", {
    body <- paste0(
      "intro\n\n",
      chapter_meta_render("Oslo", "Norway"),
      "\n\nsome trailing comment"
    )
    expect_identical(chapter_meta_parse(body)$city, "Oslo")
  })
})

describe("chapter_meta_complete", {
  meta_body <- chapter_meta_render("Oslo", "Norway", organizers = "A")

  it("fills only the fields left NULL", {
    local_mocked_bindings(
      chapter_meta_fetch = function(...) chapter_meta_parse(meta_body)
    )
    result <- chapter_meta_complete(
      list(city = "Bergen", country = NULL, region = NULL, organizers = NULL),
      5,
      "rladies",
      "repo"
    )
    expect_identical(result$city, "Bergen")
    expect_identical(result$country, "Norway")
    expect_identical(result$organizers, "A")
  })

  it("does not call the API when nothing is missing", {
    called <- FALSE
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        called <<- TRUE
        NULL
      }
    )
    chapter_meta_complete(list(city = "Oslo", country = "Norway"), 5, "o", "r")
    expect_false(called)
  })

  it("does not look the issue up just because there is no region", {
    called <- FALSE
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        called <<- TRUE
        NULL
      }
    )
    result <- chapter_meta_complete(
      list(
        city = "Oslo",
        country = "Norway",
        region = NULL,
        organizers = "A"
      ),
      5,
      "rladies",
      "repo"
    )
    expect_false(called)
    expect_null(result$region)
  })

  it("leaves fields NULL when the issue has no block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    result <- chapter_meta_complete(list(city = NULL), 5, "o", "r")
    expect_null(result$city)
  })
})

describe("chapter_onboard_website with metadata", {
  it("reads the chapter details off the issue", {
    args <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        chapter_meta_parse(chapter_meta_render(
          "Oslo",
          "Norway",
          organizers = "A"
        ))
      },
      chapter_create_pr = function(...) {
        args <<- list(...)
        "https://github.com/rladies/w/pull/1"
      },
      announce_post_reply = function(...) invisible(NULL),
      chapter_checklist_tick = function(...) TRUE
    )
    chapter_onboard_website(5)
    expect_identical(args$city, "Oslo")
    expect_identical(args$organizers, "A")
  })

  it("explains itself when the issue carries no block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    expect_error(chapter_onboard_website(5), "city and country")
  })

  it("lets an explicit argument override the issue", {
    args <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        chapter_meta_parse(chapter_meta_render("Oslo", "Norway"))
      },
      chapter_create_pr = function(...) {
        args <<- list(...)
        "https://github.com/rladies/w/pull/1"
      },
      announce_post_reply = function(...) invisible(NULL),
      chapter_checklist_tick = function(...) TRUE
    )
    chapter_onboard_website(5, city = "Bergen")
    expect_identical(args$city, "Bergen")
  })
})

describe("chapter_create_setup metadata", {
  it("embeds the block in the issue it opens", {
    posted <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        args <- list(...)
        if (grepl("issues$", endpoint)) {
          posted <<- args$body
        }
        list(number = 1, html_url = "https://example.com/1")
      },
      .package = "gh"
    )
    local_mocked_bindings(
      review_assign_onboarding = function(...) invisible(NULL),
      chapter_duplicate_comment = function(...) invisible(NULL)
    )
    chapter_create_setup("Oslo", "Norway", organizers = "A")
    meta <- chapter_meta_parse(posted)
    expect_identical(meta$city, "Oslo")
    expect_identical(meta$organizers, "A")
  })
})

describe("chapter_meta_fetch", {
  it("warns and returns NULL when the issue cannot be read", {
    local_mocked_bindings(
      gh = function(...) stop("404 Not Found"),
      .package = "gh"
    )
    expect_message(meta <- chapter_meta_fetch(5))
    expect_null(meta)
  })

  it("parses the block off an issue it can read", {
    body <- chapter_meta_render("Oslo", "Norway", organizers = "A")
    local_mocked_bindings(
      gh = function(...) list(body = body),
      .package = "gh"
    )
    expect_identical(chapter_meta_fetch(5)$city, "Oslo")
  })
})
