describe("default_welcome_channels", {
  it("returns community channel list by default", {
    channels <- default_welcome_channels()
    expect_type(channels, "list")
    expect_true(length(channels) > 0)
    names <- vapply(channels, function(c) c$name, character(1))
    expect_true("general" %in% names)
    expect_true("help-r" %in% names)
  })

  it("returns a different list for organisers", {
    organisers <- default_welcome_channels("organisers")
    community <- default_welcome_channels("community")
    organiser_names <- vapply(organisers, function(c) c$name, character(1))
    community_names <- vapply(community, function(c) c$name, character(1))
    expect_true("new-chapters" %in% organiser_names)
    expect_false("new-chapters" %in% community_names)
  })

  it("rejects unknown workspaces", {
    expect_error(default_welcome_channels("nope"))
  })
})

describe("welcome_slack_member", {
  it("aborts when SLACK_TOKEN is not set", {
    withr::with_envvar(
      c(SLACK_TOKEN = ""),
      {
        expect_error(
          welcome_slack_member("U12345"),
          "SLACK_TOKEN"
        )
      }
    )
  })

  it("aborts when user_id is empty", {
    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test"),
      {
        expect_error(
          welcome_slack_member(""),
          "user_id"
        )
      }
    )
  })

  it("rejects an unknown workspace", {
    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test"),
      {
        expect_error(welcome_slack_member("U12345", workspace = "private"))
      }
    )
  })

  it("reports an error response", {
    local_mocked_bindings(
      req_perform = function(req) structure(list(), class = "httr2_response"),
      resp_body_json = function(resp) {
        list(ok = FALSE, error = "channel_not_found")
      },
      .package = "httr2"
    )

    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test"),
      {
        expect_message(
          result <- welcome_slack_member("U12345"),
          "Failed to welcome"
        )
      }
    )
    expect_false(isTRUE(result$ok))
  })
})

describe("render_slack_welcome", {
  it("interpolates user, channels, and CoC into the community template", {
    body <- render_slack_welcome(
      user_id = "U777",
      workspace = "community",
      coc_url = "https://example.org/coc",
      welcome_channel = "welcome",
      help_channel = "community_management",
      starter_channels = default_welcome_channels("community")
    )
    expect_match(body, "RLadies\\+ Community Slack")
    expect_match(body, "<@U777>")
    expect_match(body, "https://example.org/coc")
    expect_match(body, "<#welcome>")
    expect_match(body, "<#community_management>")
    expect_match(body, "<#general>")
  })

  it("interpolates the organisers template", {
    body <- render_slack_welcome(
      user_id = "U888",
      workspace = "organisers",
      coc_url = "https://example.org/coc",
      welcome_channel = "welcome",
      help_channel = "organisers",
      starter_channels = default_welcome_channels("organisers")
    )
    expect_match(body, "RLadies\\+ Organisers Slack")
    expect_match(body, "<@U888>")
    expect_match(body, "<#new-chapters>")
  })

  it("uses custom starter channels when supplied", {
    body <- render_slack_welcome(
      user_id = "U777",
      workspace = "community",
      coc_url = "https://example.org/coc",
      welcome_channel = "welcome",
      help_channel = "community_management",
      starter_channels = list(
        list(name = "custom-chan", desc = "a custom channel description")
      )
    )
    expect_match(body, "<#custom-chan>")
    expect_match(body, "a custom channel description")
  })
})
