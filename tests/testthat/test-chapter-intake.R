intake_form <- function(
  city = "Oslo",
  country = "Norway",
  region = "_No response_",
  organizers = "Ada Lovelace, Grace Hopper"
) {
  paste0(
    "### City\n\n",
    city,
    "\n\n### Country\n\n",
    country,
    "\n\n### State, province or region\n\n",
    region,
    "\n\n### Prospective organisers\n\n",
    organizers,
    "\n"
  )
}

describe("chapter_form_parse", {
  it("reads every answer under its heading", {
    answers <- chapter_form_parse(intake_form())
    expect_identical(answers[["City"]], "Oslo")
    expect_identical(answers[["Country"]], "Norway")
    expect_identical(
      answers[["Prospective organisers"]],
      "Ada Lovelace, Grace Hopper"
    )
  })

  it("turns an unanswered optional field into an empty string", {
    answers <- chapter_form_parse(intake_form())
    expect_identical(answers[["State, province or region"]], "")
  })

  it("keeps a multi-line answer whole", {
    body <- "### Prospective organisers\n\nAda Lovelace\nGrace Hopper\n"
    expect_identical(
      chapter_form_parse(body)[["Prospective organisers"]],
      "Ada Lovelace\nGrace Hopper"
    )
  })

  it("survives CRLF line endings", {
    body <- "### City\r\n\r\nOslo\r\n\r\n### Country\r\n\r\nNorway\r\n"
    expect_identical(chapter_form_parse(body)[["City"]], "Oslo")
  })

  it("returns nothing for a body that is not a form", {
    expect_length(chapter_form_parse("Just prose about a chapter."), 0)
    expect_length(chapter_form_parse(""), 0)
    expect_length(chapter_form_parse(NULL), 0)
  })
})

describe("chapter_intake_details", {
  it("reads the chapter off the form", {
    details <- chapter_intake_details(intake_form())
    expect_identical(details$city, "Oslo")
    expect_identical(details$country, "Norway")
    expect_null(details$region)
    expect_identical(details$organizers, c("Ada Lovelace", "Grace Hopper"))
  })

  it("keeps a region when one was given", {
    expect_identical(
      chapter_intake_details(intake_form(region = "Viken"))$region,
      "Viken"
    )
  })

  it("splits organisers on newlines as well as commas", {
    details <- chapter_intake_details(
      intake_form(organizers = "Ada Lovelace\nGrace Hopper")
    )
    expect_identical(details$organizers, c("Ada Lovelace", "Grace Hopper"))
  })

  it("survives a form with no organisers", {
    details <- chapter_intake_details(intake_form(organizers = "_No response_"))
    expect_identical(details$organizers, character(0))
  })
})

describe("chapter_intake_kind", {
  it("reads the kind off the label the form applied", {
    expect_identical(chapter_intake_kind("new chapter: first contact"), "setup")
    expect_identical(chapter_intake_kind("updating chapter data"), "update")
  })

  it("ignores unrelated labels", {
    expect_identical(
      chapter_intake_kind(c("documentation", "updating chapter data")),
      "update"
    )
  })

  it("is NULL when neither label is present", {
    expect_null(chapter_intake_kind(character(0)))
    expect_null(chapter_intake_kind("bug"))
  })
})

describe("chapter_intake_title", {
  it("matches the convention the repository already uses", {
    details <- list(city = "Oslo", country = "Norway", region = NULL)
    expect_identical(
      chapter_intake_title("setup", details),
      "Oslo, Norway chapter setup"
    )
    expect_identical(
      chapter_intake_title("update", details),
      "Oslo, Norway chapter update"
    )
  })

  it("includes a region when there is one", {
    expect_identical(
      chapter_intake_title(
        "setup",
        list(city = "Edmond", country = "USA", region = "Oklahoma")
      ),
      "Edmond, Oklahoma, USA chapter setup"
    )
  })
})

describe("chapter_intake_body", {
  it("carries the checklist and the chapter details", {
    details <- list(
      city = "Oslo",
      country = "Norway",
      region = NULL,
      organizers = "Ada Lovelace"
    )
    body <- chapter_intake_body("setup", details)
    expect_match(body, "chapter-onboarding", fixed = TRUE)
    expect_match(body, "-  [ ]", fixed = TRUE)
    expect_identical(chapter_meta_parse(body)$city, "Oslo")
  })

  it("renders the update checklist for an update", {
    body <- chapter_intake_body(
      "update",
      list(
        city = "Oslo",
        country = "Norway",
        region = NULL,
        organizers = character(0)
      )
    )
    expect_match(body, "Oslo", fixed = TRUE)
    expect_identical(chapter_meta_parse(body)$country, "Norway")
  })
})

local_intake <- function(
  body = intake_form(),
  labels = list(list(name = "new chapter: first contact")),
  env = parent.frame(),
  ...
) {
  calls <- new.env(parent = emptyenv())
  calls$patched <- NULL
  calls$comment <- NULL
  calls$drafted <- NULL

  local_mocked_bindings(
    gh = function(endpoint, ...) {
      args <- list(...)
      if (startsWith(endpoint, "GET")) {
        return(list(body = body, labels = labels))
      }
      if (startsWith(endpoint, "PATCH")) {
        calls$patched <- args
      }
      list()
    },
    .package = "gh",
    .env = env
  )
  defaults <- list(
    review_assign_onboarding = function(...) invisible(NULL),
    chapter_duplicate_comment = function(...) invisible(NULL),
    chapter_meetup_draft = function(issue_number, ...) {
      calls$drafted <- issue_number
      "tok"
    },
    announce_post_reply = function(owner, repo, issue_number, body) {
      calls$comment <- body
      invisible(NULL)
    }
  )
  do.call(
    local_mocked_bindings,
    c(utils::modifyList(defaults, list(...)), list(.env = env))
  )
  calls
}

describe("chapter_intake", {
  it("rewrites the issue and runs every step", {
    calls <- local_intake()
    report <- chapter_intake(7)
    expect_identical(
      report$step,
      c("Issue set up", "Onboarding team", "Duplicate check", "Meetup draft")
    )
    expect_true(all(report$status == "done"))
  })

  it("gives the issue the conventional title and the full checklist", {
    calls <- local_intake()
    chapter_intake(7)
    expect_identical(calls$patched$title, "Oslo, Norway chapter setup")
    expect_identical(chapter_meta_parse(calls$patched$body)$city, "Oslo")
  })

  it("drafts the Meetup group for a new chapter", {
    calls <- local_intake()
    chapter_intake(7)
    expect_identical(calls$drafted, 7)
  })

  it("does not draft a group for a chapter update", {
    calls <- local_intake(labels = list(list(name = "updating chapter data")))
    report <- chapter_intake(7)
    expect_identical(report$status[report$step == "Meetup draft"], "skipped")
    expect_null(calls$drafted)
  })

  it("says nothing public has been created", {
    calls <- local_intake()
    chapter_intake(7)
    expect_match(calls$comment, "Nothing public has been created", fixed = TRUE)
  })

  it("lists the commands that work on the issue", {
    calls <- local_intake()
    chapter_intake(7)
    expect_match(calls$comment, "/jinx chapter-provision", fixed = TRUE)
    expect_match(calls$comment, "No issue number needed", fixed = TRUE)
  })

  it("carries on when the Meetup draft fails", {
    calls <- local_intake(
      chapter_meetup_draft = function(...) stop("urlname taken")
    )
    expect_message(report <- chapter_intake(7))
    expect_identical(report$status[report$step == "Meetup draft"], "failed")
    expect_identical(report$status[report$step == "Issue set up"], "done")
  })

  it("refuses an issue that is not an intake form", {
    local_intake(labels = list(list(name = "bug")))
    expect_error(chapter_intake(7), "not an onboarding intake form")
  })

  it("refuses a form with no city or country", {
    local_intake(body = intake_form(city = "_No response_"))
    expect_error(chapter_intake(7), "no city and country")
  })

  it("does nothing to an issue it has already taken over", {
    already <- paste(intake_form(), chapter_meta_render("Oslo", "Norway"))
    calls <- local_intake(body = already)
    expect_message(report <- chapter_intake(7))
    expect_identical(report$status, "skipped")
    expect_null(calls$patched)
  })
})
