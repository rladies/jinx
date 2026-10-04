describe("chapter_meetup_draft_render / _parse", {
  it("round-trips a pending draft", {
    block <- chapter_meetup_draft_render(
      "tok123",
      "rladies-oslo",
      "R-Ladies Oslo"
    )
    draft <- chapter_meetup_draft_parse(paste("Prose.\n\n", block))
    expect_identical(draft$token, "tok123")
    expect_identical(draft$urlname, "rladies-oslo")
    expect_identical(draft$name, "R-Ladies Oslo")
  })

  it("hides the block from the rendered issue", {
    block <- chapter_meetup_draft_render("t", "u", "n")
    expect_true(startsWith(block, "<!--"))
    expect_true(endsWith(block, "-->"))
  })

  it("returns NULL when there is no block", {
    expect_null(chapter_meetup_draft_parse("Just prose."))
    expect_null(chapter_meetup_draft_parse(""))
    expect_null(chapter_meetup_draft_parse(NULL))
  })

  it("returns NULL for an unreadable block", {
    body <- paste0(chapter_meetup_draft_marker(), "\nnot json\n-->")
    expect_message(expect_null(chapter_meetup_draft_parse(body)))
  })
})

describe("chapter_meetup_draft_strip", {
  it("removes the block and leaves the prose", {
    block <- chapter_meetup_draft_render("t", "u", "n")
    body <- paste0("Chapter prose here.\n\n", block)
    expect_identical(chapter_meetup_draft_strip(body), "Chapter prose here.")
  })

  it("leaves a body with no block alone", {
    expect_identical(chapter_meetup_draft_strip("Nothing here"), "Nothing here")
  })

  it("leaves other jinx blocks in place", {
    meta <- chapter_meta_render("Oslo", "Norway")
    body <- paste0(
      "Prose\n\n",
      meta,
      "\n\n",
      chapter_meetup_draft_render("t", "u", "n")
    )
    stripped <- chapter_meetup_draft_strip(body)
    expect_false(grepl(chapter_meetup_draft_marker(), stripped, fixed = TRUE))
    expect_identical(chapter_meta_parse(stripped)$city, "Oslo")
  })
})

describe("chapter_meetup_check_errors", {
  it("passes a clean payload", {
    expect_null(chapter_meetup_check_errors(list(token = "t"), "draft"))
    expect_null(chapter_meetup_check_errors(list(errors = list()), "draft"))
  })

  it("aborts with every message Meetup gave", {
    payload <- list(
      errors = list(
        list(message = "urlname taken"),
        list(message = "bad location")
      )
    )
    expect_error(
      chapter_meetup_check_errors(payload, "draft the group"),
      "urlname taken"
    )
  })
})

local_meetup <- function(
  meta = list(city = "Oslo", country = "Norway", region = NULL),
  body = "Prose",
  status = "available",
  point = c(lat = 59.91, lon = 10.75),
  query = NULL,
  env = parent.frame()
) {
  calls <- new.env(parent = emptyenv())
  calls$patched <- NULL
  calls$comment <- NULL
  calls$ticked <- NULL
  calls$input <- NULL

  local_mocked_bindings(
    gh = function(endpoint, ...) {
      args <- list(...)
      if (startsWith(endpoint, "GET")) {
        return(list(body = body))
      }
      calls$patched <- args$body
      list()
    },
    .package = "gh",
    .env = env
  )
  local_mocked_bindings(
    chapter_meta_fetch = function(...) meta,
    meetup_urlname_status = function(...) status,
    geocode_city = function(...) point,
    meetup_description_text = function() "A chapter description",
    announce_post_reply = function(owner, repo, issue_number, body) {
      calls$comment <- body
      invisible(NULL)
    },
    chapter_checklist_tick = function(issue_number, pattern, ...) {
      calls$ticked <- pattern
      TRUE
    },
    .env = env
  )
  local_mocked_bindings(
    meetupr_query = query %||%
      function(q, ...) {
        calls$input <- list(...)$input
        if (grepl("createGroupDraft", q, fixed = TRUE)) {
          list(data = list(createGroupDraft = list(token = "tok123")))
        } else {
          list(
            data = list(
              publishGroupDraft = list(
                group = list(
                  urlname = "rladies-oslo",
                  name = "R-Ladies Oslo",
                  link = "https://www.meetup.com/rladies-oslo/"
                )
              )
            )
          )
        }
      },
    .package = "meetupr",
    .env = env
  )
  calls
}

describe("chapter_meetup_draft", {
  it("drafts the group and records the token on the issue", {
    calls <- local_meetup()
    expect_identical(chapter_meetup_draft(7), "tok123")
    expect_match(calls$patched, "jinx:meetup-draft", fixed = TRUE)
    expect_identical(
      chapter_meetup_draft_parse(calls$patched)$urlname,
      "rladies-oslo"
    )
  })

  it("sends the city's own coordinates as a point location", {
    calls <- local_meetup()
    chapter_meetup_draft(7)
    expect_equal(calls$input$location$pointLocation$latitude, 59.91)
    expect_equal(calls$input$location$pointLocation$longitude, 10.75)
  })

  it("sends no topics, since a human picks those", {
    calls <- local_meetup()
    chapter_meetup_draft(7)
    expect_null(calls$input$topics)
  })

  it("says nothing is public yet", {
    calls <- local_meetup()
    chapter_meetup_draft(7)
    expect_match(calls$comment, "Nothing is public yet", fixed = TRUE)
    expect_match(calls$comment, "chapter-meetup-publish", fixed = TRUE)
  })

  it("refuses a taken urlname", {
    local_meetup(status = "taken")
    expect_error(chapter_meetup_draft(7), "already taken")
  })

  it("refuses a city it cannot geocode", {
    local_meetup(point = NULL)
    expect_error(chapter_meetup_draft(7), "Could not geocode")
  })

  it("refuses an issue with no chapter details", {
    local_meetup(meta = NULL)
    expect_error(chapter_meetup_draft(7), "no readable chapter details")
  })

  it("refuses to draft twice over a pending draft", {
    local_meetup(
      body = paste(
        "Prose",
        chapter_meetup_draft_render("t", "rladies-oslo", "n")
      )
    )
    expect_error(chapter_meetup_draft(7), "already has a draft")
  })

  it("surfaces a Meetup payload error", {
    local_meetup(
      query = function(q, ...) {
        list(
          data = list(
            createGroupDraft = list(
              errors = list(list(message = "urlname reserved"))
            )
          )
        )
      }
    )
    expect_error(chapter_meetup_draft(7), "urlname reserved")
  })

  it("aborts when Meetup returns no token", {
    local_meetup(
      query = function(q, ...) list(data = list(createGroupDraft = list()))
    )
    expect_error(chapter_meetup_draft(7), "no draft token")
  })
})

describe("chapter_meetup_publish", {
  drafted <- function() {
    paste(
      "Prose",
      chapter_meetup_draft_render("tok123", "rladies-oslo", "R-Ladies Oslo")
    )
  }

  it("publishes, announces the group and ticks the step", {
    calls <- local_meetup(body = drafted())
    expect_identical(chapter_meetup_publish(7), "rladies-oslo")
    expect_match(
      calls$comment,
      "https://www.meetup.com/rladies-oslo/",
      fixed = TRUE
    )
    expect_match(
      calls$ticked,
      "create the city chapter on Meetup",
      fixed = TRUE
    )
  })

  it("sends the token the draft recorded", {
    calls <- local_meetup(body = drafted())
    chapter_meetup_publish(7)
    expect_identical(calls$input$token, "tok123")
  })

  it("clears the pending block afterwards", {
    calls <- local_meetup(body = drafted())
    chapter_meetup_publish(7)
    expect_null(chapter_meetup_draft_parse(calls$patched))
  })

  it("points the team at chapter-provision next", {
    calls <- local_meetup(body = drafted())
    chapter_meetup_publish(7)
    expect_match(calls$comment, "chapter-provision", fixed = TRUE)
  })

  it("refuses when there is no draft", {
    local_meetup(body = "Prose with no draft")
    expect_error(chapter_meetup_publish(7), "no drafted Meetup group")
  })

  it("surfaces a Meetup payload error", {
    local_meetup(
      body = drafted(),
      query = function(q, ...) {
        list(
          data = list(
            publishGroupDraft = list(
              errors = list(list(message = "draft expired"))
            )
          )
        )
      }
    )
    expect_error(chapter_meetup_publish(7), "draft expired")
  })
})
