record <- function(
  id,
  name,
  chapter,
  status = "In progress",
  type = "New chapter"
) {
  list(
    id = id,
    fields = list(name = name, chapter = chapter, status = status, type = type)
  )
}

describe("chapter_organiser_submissions", {
  records <- list(
    record("rec1", "Ada", "Cologne, Germany"),
    record("rec2", "Grace", "Wake Forest, North Carolina EE.UU"),
    record("rec3", "Rosa", "México, Tlalnepantla, México")
  )

  it("refuses without an API key", {
    expect_error(
      chapter_organiser_submissions("Cologne", api_key = ""),
      "AIRTABLE_API_KEY"
    )
  })

  it("refuses without a city", {
    expect_error(
      chapter_organiser_submissions("", api_key = "k"),
      "without a city"
    )
  })

  it("matches the city anywhere in the free-text chapter field", {
    local_mocked_bindings(airtable_list_records = function(...) records)
    found <- chapter_organiser_submissions("Cologne", api_key = "k")
    expect_identical(found$record_id, "rec1")
  })

  it("matches despite accents and extra words", {
    local_mocked_bindings(airtable_list_records = function(...) records)
    found <- chapter_organiser_submissions("Tlalnepantla", api_key = "k")
    expect_identical(found$name, "Rosa")
  })

  it("matches a multi-word city", {
    local_mocked_bindings(airtable_list_records = function(...) records)
    found <- chapter_organiser_submissions("Wake Forest", api_key = "k")
    expect_identical(found$name, "Grace")
  })

  it("returns an empty frame when nothing matches", {
    local_mocked_bindings(airtable_list_records = function(...) records)
    expect_identical(
      nrow(chapter_organiser_submissions("Atlantis", api_key = "k")),
      0L
    )
  })
})

describe("chapter_slack_prompt_body", {
  subs <- data.frame(
    record_id = "rec1",
    name = "Ada",
    chapter = "Cologne, Germany",
    status = "In progress",
    type = "New chapter",
    stringsAsFactors = FALSE
  )

  it("says plainly when no submission has arrived", {
    body <- chapter_slack_prompt_body(chapter_submissions_empty(), "Cologne", 5)
    expect_match(body, "No organiser form submission found")
    expect_match(body, "rladies.org/form/organiser", fixed = TRUE)
  })

  it("links to the record instead of repeating the email", {
    body <- chapter_slack_prompt_body(subs, "Cologne", 5)
    expect_match(body, "airtable.com/appM6GuE0Jl1UI9qx", fixed = TRUE)
    expect_match(body, "rec1", fixed = TRUE)
    expect_false(grepl("@", body, fixed = TRUE))
  })

  it("explains why a human has to do the invite", {
    body <- chapter_slack_prompt_body(subs, "Cologne", 5)
    expect_match(body, "no API for workspace invites")
    expect_match(body, "Enterprise")
  })

  it("names the submitter and how to confirm", {
    body <- chapter_slack_prompt_body(subs, "Cologne", 5)
    expect_match(body, "Ada")
    expect_match(body, "chapter-slack-sent 5", fixed = TRUE)
  })
})

describe("chapter_slack_prompt", {
  it("reads the city off the issue and posts the prompt", {
    posted <- NULL
    local_mocked_bindings(
      chapter_meta_fetch = function(...) list(city = "Cologne"),
      chapter_organiser_submissions = function(...) chapter_submissions_empty(),
      announce_post_reply = function(org, repo, number, body) posted <<- body
    )
    chapter_slack_prompt(5)
    expect_match(posted, "Cologne")
  })

  it("refuses when the issue carries no chapter block", {
    local_mocked_bindings(chapter_meta_fetch = function(...) NULL)
    expect_error(chapter_slack_prompt(5), "without a city")
  })
})

describe("chapter_slack_sent", {
  it("ticks the Organizers Slack step, not the Community one", {
    body <- paste(
      "-  [ ] invite prospective organizers to the RLadies+ Community Slack",
      paste(
        "-  [ ] if everything looks good in the form, invite organizers",
        "to the RLadies+ Organizers Slack"
      ),
      sep = "\n"
    )
    patched <- NULL
    local_mocked_bindings(
      gh = function(endpoint, ...) {
        if (startsWith(endpoint, "GET")) {
          return(list(body = body))
        }
        patched <<- list(...)$body
        list()
      },
      .package = "gh"
    )
    expect_message(expect_true(chapter_slack_sent(5)))
    expect_match(patched, "\\[x\\] if everything looks good")
    expect_match(patched, "\\[ \\] invite prospective organizers")
  })
})

describe("/jinx chapter-slack parsing", {
  it("takes an issue number", {
    expect_identical(
      cmd_parse("/jinx chapter-slack 12"),
      list(action = "chapter-slack", issue = 12L)
    )
  })

  it("distinguishes the confirm command from the prompt", {
    expect_identical(
      cmd_parse("/jinx chapter-slack-sent 12")$action,
      "chapter-slack-sent"
    )
    expect_identical(
      cmd_parse("/jinx chapter slack sent 12")$action,
      "chapter-slack-sent"
    )
    expect_identical(
      cmd_parse("/jinx chapter slack 12")$action,
      "chapter-slack"
    )
  })

  it("explains itself without an issue number", {
    parsed <- cmd_parse("/jinx chapter-slack")
    expect_identical(parsed$action, "error")
    expect_match(parsed$message, "issue number")
  })

  it("both are gated, since they comment on and edit an issue", {
    expect_identical(jinx_commands()[["chapter-slack"]]$keyword, "jinx_gated")
    expect_identical(
      jinx_commands()[["chapter-slack-sent"]]$keyword,
      "jinx_gated"
    )
  })
})
