library(httr2)

describe("chapter_meetup_urlname", {
  it("hyphenates multi-word cities", {
    expect_identical(
      chapter_meetup_urlname("Buenos Aires"),
      "rladies-buenos-aires"
    )
  })

  it("transliterates the way the website filenames do", {
    expect_identical(chapter_meetup_urlname("Córdoba"), "rladies-cordoba")
    expect_identical(chapter_meetup_urlname("São Paulo"), "rladies-sao-paulo")
  })

  it("refuses a city that slugs to nothing", {
    expect_error(chapter_meetup_urlname("!!!"), "Cannot build")
    expect_error(chapter_meetup_urlname(""), "Cannot build")
  })
})

describe("chapter_meetup_name", {
  it("prefixes the city as written", {
    expect_identical(chapter_meetup_name("Córdoba"), "RLadies+ Córdoba")
    expect_identical(chapter_meetup_name("  Oslo  "), "RLadies+ Oslo")
  })

  it("refuses an empty city", {
    expect_error(chapter_meetup_name(""), "without a city")
    expect_error(chapter_meetup_name(NULL), "without a city")
  })
})

describe("meetup_urlname_status", {
  it("calls a page carrying the not-found copy available", {
    local_mocked_responses(list(response(
      body = charToRaw("... Group not found ...")
    )))
    expect_identical(meetup_urlname_status("rladies-nowhere"), "available")
  })

  it("calls any other page taken", {
    local_mocked_responses(list(response(
      body = charToRaw("<html>RLadies+ Oslo</html>")
    )))
    expect_identical(meetup_urlname_status("rladies-oslo"), "taken")
  })

  it("says unknown rather than guessing when the fetch fails", {
    local_mocked_responses(function(req) stop("network down"))
    expect_identical(meetup_urlname_status("rladies-oslo"), "unknown")
  })

  it("says unknown on an empty body", {
    local_mocked_responses(list(response(body = charToRaw(""))))
    expect_identical(meetup_urlname_status("rladies-oslo"), "unknown")
  })
})

describe("chapter_meetup_brief", {
  it("spells out the name and URL that cannot be changed later", {
    body <- chapter_meetup_brief("Oslo", "Norway")
    expect_match(body, "RLadies+ Oslo", fixed = TRUE)
    expect_match(body, "https://www.meetup.com/rladies-oslo/", fixed = TRUE)
    expect_match(body, "cannot be changed after creation")
  })

  it("includes the settings the guidelines call for", {
    body <- chapter_meetup_brief("Oslo", "Norway")
    expect_match(body, "Technology, or Data Science", fixed = TRUE)
    expect_match(body, "Member label | RLadies+", fixed = TRUE)
    expect_match(body, "Oslo, Norway", fixed = TRUE)
  })

  it("carries the description with the parts that must stay", {
    body <- chapter_meetup_brief("Oslo", "Norway")
    expect_match(body, "https://rladies.org/coc/", fixed = TRUE)
    expect_match(body, "photography/video filming/media", fixed = TRUE)
    expect_match(body, "promotes gender diversity", fixed = TRUE)
  })

  it("reminds about the co-organiser step", {
    body <- chapter_meetup_brief("Oslo", "Norway")
    expect_match(body, "co-organiser")
    expect_match(body, "must not be cis men")
  })

  it("omits the availability line when no status is given", {
    body <- chapter_meetup_brief("Oslo", "Norway", status = NULL)
    expect_false(grepl("looks free|looks taken|Could not tell", body))
  })

  it("flags a taken urlname prominently", {
    body <- chapter_meetup_brief("Oslo", "Norway", status = "taken")
    expect_match(body, "looks taken")
    expect_match(body, "Meetup Pro account manager")
  })

  it("hedges an available urlname rather than asserting it", {
    body <- chapter_meetup_brief("Oslo", "Norway", status = "available")
    expect_match(body, "looks free")
    expect_match(body, "not an API")
  })

  it("says so when it could not tell", {
    body <- chapter_meetup_brief("Oslo", "Norway", status = "unknown")
    expect_match(body, "Could not tell")
  })
})

describe("chapter_meetup_request", {
  it("reads the chapter off the issue and posts the brief", {
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        list(city = "Oslo", country = "Norway")
      },
      meetup_urlname_status = function(...) "available",
      announce_post_reply = function(org, repo, number, body) posted <<- body
    )
    body <- chapter_meetup_request(5)
    expect_match(posted, "rladies-oslo", fixed = TRUE)
    expect_identical(body, posted)
  })

  it("refuses when the issue carries no chapter block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    expect_error(chapter_meetup_request(5), "city and country")
  })

  it("lets explicit arguments win without reading the issue", {
    called <- FALSE
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) {
        called <<- TRUE
        NULL
      },
      meetup_urlname_status = function(...) "unknown",
      announce_post_reply = function(org, repo, number, body) posted <<- body
    )
    chapter_meetup_request(5, city = "Bergen", country = "Norway")
    expect_false(called)
    expect_match(posted, "rladies-bergen", fixed = TRUE)
  })
})

describe("/jinx chapter-meetup parsing", {
  it("takes an issue number", {
    expect_identical(
      cmd_parse("/jinx chapter-meetup 12"),
      list(action = "chapter-meetup", issue = 12L)
    )
  })

  it("accepts the spelled-out phrasing", {
    expect_identical(cmd_parse("/jinx chapter meetup 12")$issue, 12L)
  })

  it("refuses a city, since the brief comes from the issue", {
    parsed <- cmd_parse("/jinx chapter-meetup Oslo")
    expect_identical(parsed$action, "error")
    expect_match(parsed$message, "issue number")
  })
})

describe("chapter-meetup privilege", {
  it("is gated, since it comments on an onboarding issue", {
    expect_identical(jinx_commands()[["chapter-meetup"]]$keyword, "jinx_gated")
  })
})

describe("the urlname convention note", {
  it("says a chapter may ask for a different urlname", {
    body <- chapter_meetup_brief("Portland", "USA")
    expect_match(body, "rladies-pdx", fixed = TRUE)
    expect_match(body, "cannot be changed afterwards")
  })
})
