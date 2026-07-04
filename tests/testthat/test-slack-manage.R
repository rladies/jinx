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
