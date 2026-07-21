library(httr2)

describe("is_valid_email", {
  it("accepts a normal email", {
    expect_true(is_valid_email("ada@example.com"))
  })

  it("rejects strings without an @", {
    expect_false(is_valid_email("not-an-email"))
  })

  it("rejects strings without a dot in the domain", {
    expect_false(is_valid_email("foo@bar"))
  })

  it("rejects strings with whitespace", {
    expect_false(is_valid_email("ada @example.com"))
    expect_false(is_valid_email("ada@example .com"))
  })

  it("rejects empty input", {
    expect_false(is_valid_email(""))
  })
})

describe("review_invite_message", {
  it("includes the email and admin instructions", {
    msg <- review_invite_message("ada@example.com")
    expect_match(as.character(msg), "ada@example.com", fixed = TRUE)
    expect_match(as.character(msg), "Invite people to RLadies", fixed = TRUE)
  })
})

describe("slack_invite_request", {
  it("aborts when SLACK_TOKEN is not set", {
    withr::with_envvar(
      c(SLACK_TOKEN = "", AIRTABLE_API_KEY = "key"),
      {
        expect_error(
          slack_invite_request("ada@example.com"),
          "SLACK_TOKEN"
        )
      }
    )
  })

  it("returns an error string for a malformed email", {
    local_mocked_bindings(
      slack_post_message = function(...) {
        stop("should not be called for invalid email")
      }
    )
    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test", AIRTABLE_API_KEY = "key"),
      {
        result <- slack_invite_request("not-an-email")
        expect_match(as.character(result), "Invalid email address")
      }
    )
  })

  it("posts the request to the configured channel and marks Airtable", {
    post_args <- NULL
    airtable_args <- NULL
    local_mocked_bindings(
      slack_post_message = function(text, channel, token) {
        post_args <<- list(text = text, channel = channel, token = token)
        list(ok = TRUE)
      }
    )
    local_mocked_bindings(
      airtable_mark_invited = function(email, base_id, api_key) {
        airtable_args <<- list(email = email, api_key = api_key)
        TRUE
      }
    )

    withr::with_envvar(
      c(
        SLACK_TOKEN = "xoxb-test",
        AIRTABLE_API_KEY = "secret",
        SLACK_INVITE_REQUEST_CHANNEL = "organisers"
      ),
      {
        result <- slack_invite_request("ada@example.com")
        expect_match(
          as.character(result),
          "Invite request for ada@example.com posted to #organisers"
        )
      }
    )
    expect_identical(post_args$channel, "organisers")
    expect_match(post_args$text, "ada@example.com", fixed = TRUE)
    expect_identical(airtable_args$email, "ada@example.com")
  })

  it("defaults to the global-team channel when env var is unset", {
    post_args <- NULL
    local_mocked_bindings(
      slack_post_message = function(text, channel, token) {
        post_args <<- list(channel = channel)
        list(ok = TRUE)
      }
    )
    local_mocked_bindings(
      airtable_mark_invited = function(...) TRUE
    )

    withr::with_envvar(
      c(
        SLACK_TOKEN = "xoxb-test",
        AIRTABLE_API_KEY = "secret",
        SLACK_INVITE_REQUEST_CHANNEL = ""
      ),
      {
        slack_invite_request("ada@example.com")
      }
    )
    expect_identical(post_args$channel, "global-team")
  })

  it("skips Airtable when AIRTABLE_API_KEY is unset", {
    local_mocked_bindings(
      slack_post_message = function(text, channel, token) list(ok = TRUE)
    )
    local_mocked_bindings(
      airtable_mark_invited = function(...) {
        stop("should not be called when AIRTABLE_API_KEY is empty")
      }
    )

    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test", AIRTABLE_API_KEY = ""),
      {
        result <- slack_invite_request("ada@example.com")
        expect_match(as.character(result), "posted to #")
      }
    )
  })

  it("aborts when the Slack post fails and does not mark Airtable", {
    local_mocked_bindings(
      slack_post_message = function(text, channel, token) {
        list(ok = FALSE, error = "channel_not_found")
      }
    )
    local_mocked_bindings(
      airtable_mark_invited = function(...) {
        stop("should not be called when Slack post failed")
      }
    )

    withr::with_envvar(
      c(SLACK_TOKEN = "xoxb-test", AIRTABLE_API_KEY = "secret"),
      {
        expect_error(
          slack_invite_request("ada@example.com"),
          "channel_not_found"
        )
      }
    )
  })
})

describe("slack_api_call", {
  it("returns the parsed response on success", {
    local_mocked_responses(list(
      response_json(body = list(ok = TRUE, channel = list(id = "D1")))
    ))
    resp <- slack_api_call(
      "xoxb-test",
      "conversations.open",
      list(users = "U1")
    )
    expect_true(resp$ok)
    expect_identical(resp$channel$id, "D1")
  })

  it("aborts when ok is FALSE", {
    local_mocked_responses(list(
      response_json(body = list(ok = FALSE, error = "channel_not_found"))
    ))
    expect_error(
      slack_api_call("xoxb-test", "conversations.open", list(users = "U1")),
      "channel_not_found"
    )
  })

  it("aborts when no token is set", {
    expect_error(slack_api_call("", "conversations.open"), "token")
  })
})

describe("slack_bot_token", {
  it("resolves the organiser token", {
    withr::with_envvar(
      c(SLACK_ORGANISER_TOKEN = "xoxb-org", SLACK_COMMUNITY_TOKEN = "xoxb-com"),
      expect_identical(slack_bot_token("organiser"), "xoxb-org")
    )
  })

  it("resolves the community token", {
    withr::with_envvar(
      c(SLACK_ORGANISER_TOKEN = "xoxb-org", SLACK_COMMUNITY_TOKEN = "xoxb-com"),
      expect_identical(slack_bot_token("community"), "xoxb-com")
    )
  })

  it("aborts when the token for the workspace is unset", {
    withr::with_envvar(
      c(SLACK_COMMUNITY_TOKEN = ""),
      expect_error(slack_bot_token("community"), "community")
    )
  })
})

describe("slack_workspace_for_team", {
  it("maps the organiser team id", {
    expect_identical(
      slack_workspace_for_team(
        "T_ORG",
        organiser_id = "T_ORG",
        community_id = "T_COM"
      ),
      "organiser"
    )
  })

  it("maps the community team id", {
    expect_identical(
      slack_workspace_for_team(
        "T_COM",
        organiser_id = "T_ORG",
        community_id = "T_COM"
      ),
      "community"
    )
  })

  it("aborts for an unrecognised team id", {
    expect_error(
      slack_workspace_for_team(
        "T_OTHER",
        organiser_id = "T_ORG",
        community_id = "T_COM"
      ),
      "not a recognised workspace"
    )
  })
})

describe("slack_response_url_post", {
  it("posts the replacement body", {
    captured <- NULL
    local_mocked_bindings(
      req_perform = function(req) {
        captured <<- req
        httr2::response(body = charToRaw("ok"))
      },
      .package = "httr2"
    )
    slack_response_url_post(
      "https://hooks.slack.com/actions/T1/1/abc",
      text = "Approved",
      replace_original = TRUE
    )
    expect_identical(captured$body$data$text, "Approved")
    expect_true(captured$body$data$replace_original)
  })

  it("refuses to post to a URL that isn't a hooks.slack.com response_url", {
    expect_error(
      slack_response_url_post(
        "https://attacker.example/collect",
        text = "Approved"
      ),
      "hooks\\.slack\\.com"
    )
  })
})

describe("slack_subscribe_rss", {
  it("posts a human-actionable /feed subscribe request", {
    post_args <- NULL
    local_mocked_bindings(
      slack_post_message = function(text, channel, token) {
        post_args <<- list(text = text, channel = channel)
        list(ok = TRUE)
      }
    )

    suppressMessages(
      slack_subscribe_rss(
        "https://example.com/feed.xml",
        channel = "rladiesblogs"
      )
    )

    expect_identical(post_args$channel, "rladiesblogs")
    expect_match(post_args$text, "/feed subscribe https://example.com/feed.xml")
  })
})
