describe("promo_clean_description", {
  it("keeps a link's label and drops the URL", {
    expect_identical(
      promo_clean_description("See <https://guide.rladies.org|the guide>"),
      "See the guide"
    )
  })

  it("strips bare URLs and angle-bracket mentions", {
    expect_identical(
      promo_clean_description(
        "Chat here <#C1> or visit https://rladies.org now"
      ),
      "Chat here or visit now"
    )
  })

  it("collapses whitespace and trims", {
    expect_identical(
      promo_clean_description("  lots   of\n\n  space "),
      "lots of space"
    )
  })

  it("returns an empty string for NULL or NA", {
    expect_identical(promo_clean_description(NULL), "")
    expect_identical(promo_clean_description(NA), "")
  })
})

describe("promo_eligible_channels", {
  channels <- list(
    list(
      id = "C1",
      name = "career-advice",
      purpose = list(value = "Career Q&A")
    ),
    list(id = "C2", name = "general", purpose = list(value = "Announcements")),
    list(id = "C3", name = "quiet", purpose = list(value = "")),
    list(
      id = "C4",
      name = "old",
      is_archived = TRUE,
      purpose = list(value = "Archived")
    ),
    list(
      id = "C5",
      name = "random",
      purpose = list(value = "Off-topic chatter")
    )
  )

  it("keeps only non-archived channels that have a description", {
    eligible <- promo_eligible_channels(channels, target_channel = "general")
    expect_setequal(eligible$name, c("career-advice", "random"))
  })

  it("excludes the target channel and any skipped names", {
    eligible <- promo_eligible_channels(
      channels,
      target_channel = "general",
      skip = "random"
    )
    expect_identical(eligible$name, "career-advice")
  })

  it("cleans the description it keeps", {
    channels <- list(
      list(
        id = "C1",
        name = "events",
        purpose = list(value = "Meetups <https://rladies.org|here> weekly")
      )
    )
    eligible <- promo_eligible_channels(channels)
    expect_identical(eligible$description, "Meetups here weekly")
  })

  it("returns an empty data frame when nothing is eligible", {
    expect_identical(nrow(promo_eligible_channels(list())), 0L)
    expect_identical(nrow(promo_eligible_channels(NULL)), 0L)
  })
})

describe("promo_pick_channel", {
  eligible <- data.frame(
    id = c("C1", "C2", "C3"),
    name = c("career-advice", "events", "random"),
    description = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )

  it("picks the alphabetically-first channel not featured this cycle", {
    picked <- promo_pick_channel(eligible, recent = character())
    expect_identical(picked$channel$name, "career-advice")
    expect_identical(picked$recent, "C1")
  })

  it("skips channels already in recent and appends the new pick", {
    picked <- promo_pick_channel(eligible, recent = c("C1"))
    expect_identical(picked$channel$name, "events")
    expect_identical(picked$recent, c("C1", "C2"))
  })

  it("resets the cycle once every channel has been featured", {
    picked <- promo_pick_channel(eligible, recent = c("C1", "C2", "C3"))
    expect_identical(picked$channel$name, "career-advice")
    expect_identical(picked$recent, "C1")
  })

  it("prunes ids from recent that are no longer eligible", {
    picked <- promo_pick_channel(eligible, recent = c("C1", "C9-archived"))
    expect_identical(picked$channel$name, "events")
    expect_identical(picked$recent, c("C1", "C2"))
  })

  it("returns NULL when nothing is eligible", {
    expect_null(promo_pick_channel(eligible[0, ], recent = character()))
  })
})

describe("promo_blurb", {
  it("returns the trimmed model response on success", {
    local_mocked_bindings(
      cloudflare_generate = function(...) "  Come join the fun.  "
    )
    expect_identical(
      promo_blurb("random", "chatter", account_id = "a", api_token = "t"),
      "Come join the fun."
    )
  })

  it("returns NULL when the model responds with nothing usable", {
    local_mocked_bindings(cloudflare_generate = function(...) "   ")
    expect_null(promo_blurb(
      "random",
      "chatter",
      account_id = "a",
      api_token = "t"
    ))
  })

  it("returns NULL and warns when the model call errors", {
    local_mocked_bindings(
      cloudflare_generate = function(...) cli::cli_abort("boom")
    )
    expect_warning(
      result <- promo_blurb(
        "random",
        "chatter",
        account_id = "a",
        api_token = "t"
      ),
      "promo_blurb failed"
    )
    expect_null(result)
  })
})

describe("channel_promo_format", {
  it("links the featured channel and appends the blurb", {
    md <- channel_promo_format("C1", "career-advice", "Come say hi!")
    expect_match(md, "Channel spotlight:", fixed = TRUE)
    expect_match(md, "<#C1|career-advice>", fixed = TRUE)
    expect_match(md, "Come say hi!", fixed = TRUE)
  })

  it("escapes injected mentions and links in the blurb", {
    md <- channel_promo_format(
      "C1",
      "career-advice",
      "Join <!channel> and click <https://evil.example|here>"
    )
    expect_false(grepl("<!channel>", md, fixed = TRUE))
    expect_false(grepl("<https://evil.example|here>", md, fixed = TRUE))
    expect_match(md, "&lt;!channel&gt;", fixed = TRUE)
  })
})

describe("promo_fallback_blurb", {
  it("wraps the description as the invitation", {
    expect_match(
      promo_fallback_blurb("Career questions and advice"),
      "Career questions and advice",
      fixed = TRUE
    )
  })
})

describe("channel_promo_build", {
  channels <- list(
    list(
      id = "C1",
      name = "career-advice",
      purpose = list(value = "Career questions and advice")
    ),
    list(id = "C2", name = "general", purpose = list(value = "Announcements"))
  )

  it("builds a spotlight for the picked channel", {
    local_mocked_bindings(
      slack_conversations_list = function(...) channels,
      promo_recent_load = function(...) character(),
      promo_blurb = function(...) "Warm welcome!"
    )
    built <- channel_promo_build(
      team_id = "T",
      target_channel = "general",
      skip = character(),
      account_id = "a",
      api_token = "t"
    )
    expect_identical(built$channel_id, "C1")
    expect_identical(built$channel_name, "career-advice")
    expect_identical(built$recent, "C1")
    expect_match(built$text, "<#C1|career-advice>", fixed = TRUE)
    expect_match(built$text, "Warm welcome!", fixed = TRUE)
  })

  it("falls back to the description when the model draft fails", {
    local_mocked_bindings(
      slack_conversations_list = function(...) channels,
      promo_recent_load = function(...) character(),
      promo_blurb = function(...) NULL
    )
    built <- channel_promo_build(
      team_id = "T",
      target_channel = "general",
      skip = character(),
      account_id = "a",
      api_token = "t"
    )
    expect_match(built$text, "Career questions and advice", fixed = TRUE)
  })

  it("returns NULL when no channel is eligible", {
    local_mocked_bindings(
      slack_conversations_list = function(...) {
        list(list(id = "C2", name = "general", purpose = list(value = "hi")))
      },
      promo_recent_load = function(...) character()
    )
    expect_message(
      result <- channel_promo_build(
        team_id = "T",
        target_channel = "general",
        skip = character(),
        account_id = "a",
        api_token = "t"
      ),
      "No community channels"
    )
    expect_null(result)
  })
})

describe("channel_promo_post", {
  it("posts the spotlight and records the pick", {
    posted <- list()
    saved <- list()
    local_mocked_bindings(
      channel_promo_build = function(...) {
        list(
          text = "the spotlight",
          channel_id = "C1",
          channel_name = "career-advice",
          recent = "C1"
        )
      },
      slack_post_message = function(text, channel, token) {
        posted[["text"]] <<- text
        posted[["channel"]] <<- channel
        list(ok = TRUE)
      },
      promo_recent_save = function(team_id, recent, ...) {
        saved[["recent"]] <<- recent
        invisible(TRUE)
      }
    )
    expect_message(
      result <- channel_promo_post(
        team_id = "T",
        target_channel = "general",
        slack_token = "tok"
      ),
      "Spotlighted"
    )
    expect_true(result)
    expect_identical(posted$text, "the spotlight")
    expect_identical(posted$channel, "general")
    expect_identical(saved$recent, "C1")
  })

  it("returns FALSE and neither posts nor records when nothing is eligible", {
    posted <- FALSE
    saved <- FALSE
    local_mocked_bindings(
      channel_promo_build = function(...) NULL,
      slack_post_message = function(...) {
        posted <<- TRUE
        list(ok = TRUE)
      },
      promo_recent_save = function(...) {
        saved <<- TRUE
        invisible(TRUE)
      }
    )
    expect_message(
      result <- channel_promo_post(
        team_id = "T",
        target_channel = "general",
        slack_token = "tok"
      ),
      "No channel spotlight"
    )
    expect_false(result)
    expect_false(posted)
    expect_false(saved)
  })

  it("aborts and does not record the pick when the Slack post fails", {
    saved <- FALSE
    local_mocked_bindings(
      channel_promo_build = function(...) {
        list(
          text = "the spotlight",
          channel_id = "C1",
          channel_name = "career-advice",
          recent = "C1"
        )
      },
      slack_post_message = function(...) {
        list(ok = FALSE, error = "not_in_channel")
      },
      promo_recent_save = function(...) {
        saved <<- TRUE
        invisible(TRUE)
      }
    )
    expect_error(
      channel_promo_post(
        team_id = "T",
        target_channel = "general",
        slack_token = "tok"
      ),
      "not_in_channel"
    )
    expect_false(saved)
  })
})
