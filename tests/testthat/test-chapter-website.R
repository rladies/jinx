describe("chapter_entry_json", {
  it("omits urlname and leaves social_media empty for a prospective chapter", {
    json <- chapter_entry_json(
      "Arcata",
      "USA",
      region = "California",
      organizers = "Shannon Boyle"
    )
    expect_false(grepl("urlname", json))
    expect_match(json, '"social_media": {}', fixed = TRUE)
    expect_match(json, '"state.region": "California"', fixed = TRUE)
  })

  it("keeps a single organiser as an array, not a nested one", {
    json <- chapter_entry_json("Oslo", "Norway", organizers = "Solo")
    expect_match(json, '"current": ["Solo"]', fixed = TRUE)
  })

  it("writes social media handles as scalars", {
    json <- chapter_entry_json(
      "Oslo",
      "Norway",
      meetup_urlname = "rladies-oslo",
      email = "oslo@rladies.org",
      status = "active"
    )
    expect_match(json, '"meetup": "rladies-oslo"', fixed = TRUE)
    expect_match(json, '"urlname": "rladies-oslo"', fixed = TRUE)
  })

  it("always records an empty former organisers list", {
    json <- chapter_entry_json("Oslo", "Norway", organizers = "A")
    expect_match(json, '"former": []', fixed = TRUE)
  })
})

describe("chapter_entry_validate", {
  it("accepts a prospective entry", {
    json <- chapter_entry_json("Arcata", "USA", organizers = "Shannon Boyle")
    expect_true(chapter_entry_validate(json))
  })

  it("accepts a fully populated entry", {
    json <- chapter_entry_json(
      "Oslo",
      "Norway",
      meetup_urlname = "rladies-oslo",
      email = "oslo@rladies.org",
      organizers = c("A", "B"),
      status = "active"
    )
    expect_true(chapter_entry_validate(json))
  })

  it("rejects an entry missing a required field", {
    expect_error(
      chapter_entry_validate('{"city": "Oslo"}'),
      "does not match the schema"
    )
  })
})

describe("chapter_pr_body", {
  it("says so when there is no Meetup group or organiser yet", {
    body <- chapter_pr_body("Oslo", "Norway", "prospective", NULL, character(0))
    expect_match(body, "Meetup: not created yet")
    expect_match(body, "Organizers: to be confirmed")
  })

  it("lists the Meetup group and organisers when known", {
    body <- chapter_pr_body(
      "Oslo",
      "Norway",
      "active",
      "rladies-oslo",
      c("A", "B")
    )
    expect_match(body, "Meetup: rladies-oslo")
    expect_match(body, "Organizers: A, B")
  })
})

describe("checklist_tick_body", {
  body <- paste(
    "-  [x] already done",
    "-  [ ] add prospective chapter to the current chapters on the website",
    "-  [ ] something else",
    sep = "\n"
  )

  it("ticks the first unchecked item that matches", {
    updated <- checklist_tick_body(body, "chapters on the website")
    expect_match(updated, "[x] add prospective chapter", fixed = TRUE)
    expect_match(updated, "[ ] something else", fixed = TRUE)
  })

  it("returns NULL when nothing matches", {
    expect_null(checklist_tick_body(body, "create the chapter email"))
  })

  it("returns NULL when the only match is already ticked", {
    expect_null(checklist_tick_body(body, "already done"))
  })

  it("survives an empty body", {
    expect_null(checklist_tick_body("", "anything"))
  })
})

describe("chapter_checklist_tick", {
  it("patches the issue when an item is ticked", {
    patched <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        args <- list(...)
        if (startsWith(endpoint, "GET")) {
          return(list(body = "-  [ ] create the chapter email"))
        }
        patched <<- args$body
        list()
      },
      .package = "gh"
    )
    expect_true(chapter_checklist_tick(5, "create the chapter email"))
    expect_match(patched, "[x] create the chapter email", fixed = TRUE)
  })

  it("leaves the issue alone when nothing matches", {
    patched <- FALSE
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (startsWith(endpoint, "GET")) {
          return(list(body = "-  [ ] a different step"))
        }
        patched <<- TRUE
        list()
      },
      .package = "gh"
    )
    expect_message(result <- chapter_checklist_tick(5, "chapter email"))
    expect_false(result)
    expect_false(patched)
  })
})

describe("chapter_onboard_website", {
  it("opens the PR, links it on the issue, and ticks the step", {
    comment <- NULL
    ticked <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) NULL,
      chapter_create_pr = function(...) "https://github.com/rladies/w/pull/1",
      announce_post_reply = function(org, repo, number, body) comment <<- body,
      chapter_checklist_tick = function(number, pattern, ...) {
        ticked <<- pattern
        TRUE
      }
    )
    url <- chapter_onboard_website(5, "Oslo", "Norway", organizers = "A")
    expect_identical(url, "https://github.com/rladies/w/pull/1")
    expect_match(comment, "prospective")
    expect_match(comment, "@rladies/leadership", fixed = TRUE)
    expect_match(ticked, "chapters on the website")
  })

  it("asks for a prospective entry with no email or meetup", {
    args <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) NULL,
      chapter_create_pr = function(...) {
        args <<- list(...)
        "https://github.com/rladies/w/pull/1"
      },
      announce_post_reply = function(...) invisible(NULL),
      chapter_checklist_tick = function(...) TRUE
    )
    chapter_onboard_website(5, "Oslo", "Norway")
    expect_identical(args$status, "prospective")
    expect_null(args$email)
    expect_null(args$meetup_urlname)
  })
})

describe("gh_request_team_review", {
  it("does nothing without reviewers", {
    expect_false(gh_request_team_review("rladies", "repo", 1, NULL))
  })

  it("posts the team slugs", {
    sent <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        sent <<- list(...)$team_reviewers
        list()
      },
      .package = "gh"
    )
    expect_true(gh_request_team_review("rladies", "repo", 1, "leadership"))
    expect_identical(sent, list("leadership"))
  })

  it("warns but carries on when the request fails", {
    local_mocked_bindings(
      gh = function(...) stop("no such team"),
      .package = "gh"
    )
    expect_message(result <- gh_request_team_review("r", "repo", 1, "nope"))
    expect_false(result)
  })
})
