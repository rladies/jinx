library(httr2)

describe("pending_link_key", {
  it("normalises case and whitespace", {
    expect_identical(
      pending_link_key("  Foo@Bar.Com  "),
      "pending_link:foo@bar.com"
    )
  })
})

describe("not_provided", {
  it("returns the placeholder for NULL or empty input", {
    expect_identical(not_provided(NULL), "_not provided_")
    expect_identical(not_provided(""), "_not provided_")
  })

  it("returns the value when present", {
    expect_identical(not_provided("Oslo"), "Oslo")
  })
})

describe("airtable_record_update", {
  it("PATCHes the record with the given fields", {
    captured <- NULL
    local_mocked_bindings(
      req_perform = function(req) {
        captured <<- req
        httr2::response_json(
          body = list(id = "rec1", fields = list(invited = TRUE))
        )
      },
      .package = "httr2"
    )
    airtable_record_update(
      "app1",
      "tbl1",
      "rec1",
      list(invited = TRUE),
      api_key = "key"
    )
    expect_identical(captured$method, "PATCH")
    expect_identical(captured$body$data$fields$invited, TRUE)
    expect_match(captured$url, "app1/tbl1/rec1", fixed = TRUE)
  })
})

describe("airtable_base_allowed", {
  it("returns TRUE when the base is in the cached allowlist", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) {
        jsonlite::toJSON(
          list(bases = list("app123"), fetched_at = "2026-01-01"),
          auto_unbox = TRUE
        )
      },
      airtable_meta_bases_fetch = function(...) {
        stop("should not be called on a cache hit")
      }
    )
    expect_true(airtable_base_allowed("app123"))
  })

  it("returns FALSE when the base is not in the cached allowlist", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) {
        jsonlite::toJSON(
          list(bases = list("app999"), fetched_at = "2026-01-01"),
          auto_unbox = TRUE
        )
      }
    )
    expect_false(airtable_base_allowed("app123"))
  })

  it("refreshes from the Meta API on a cache miss and writes the cache back", {
    put_args <- NULL
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) stop("not found"),
      airtable_meta_bases_fetch = function(...) c("app123", "app456"),
      cf_ops_kv_put = function(...) {
        put_args <<- list(...)
        invisible(TRUE)
      }
    )
    expect_true(airtable_base_allowed("app456"))
    expect_identical(put_args$key_name, "allowed_bases")
  })

  it("returns FALSE for an empty base_id", {
    expect_false(airtable_base_allowed(""))
  })
})

describe("slack_invite_request_blocks", {
  it("includes approve/deny buttons and the display fields", {
    blocks <- slack_invite_request_blocks(
      "ada@example.com",
      "Ada",
      "Oslo",
      "rec1",
      "app1",
      "tbl1"
    )
    actions <- blocks[[3]]$elements
    action_ids <- vapply(actions, function(a) a$action_id, character(1))
    expect_setequal(action_ids, c("invite_approve", "invite_deny"))

    fields <- blocks[[2]]$fields
    field_text <- vapply(fields, function(f) f$text, character(1))
    expect_true(any(grepl("Ada", field_text, fixed = TRUE)))
    expect_true(any(grepl("ada@example.com", field_text, fixed = TRUE)))
    expect_true(any(grepl("Oslo", field_text, fixed = TRUE)))
  })

  it("shows a placeholder for a missing name or chapter", {
    blocks <- slack_invite_request_blocks(
      "ada@example.com",
      NULL,
      NULL,
      "rec1",
      "app1",
      "tbl1"
    )
    fields <- blocks[[2]]$fields
    field_text <- vapply(fields, function(f) f$text, character(1))
    expect_true(any(grepl("_not provided_", field_text, fixed = TRUE)))
  })

  it("does not include chapter in the button value payload", {
    blocks <- slack_invite_request_blocks(
      "ada@example.com",
      "Ada",
      "Oslo",
      "rec1",
      "app1",
      "tbl1"
    )
    value <- jsonlite::fromJSON(blocks[[3]]$elements[[1]]$value)
    expect_null(value$chapter)
    expect_identical(value$email, "ada@example.com")
  })
})

describe("slack_invite_approval_checklist_blocks", {
  it("includes the mark-sent button with the record identifiers", {
    blocks <- slack_invite_approval_checklist_blocks(
      "ada@example.com",
      "bob",
      "rec1",
      "app1",
      "tbl1"
    )
    button <- blocks[[4]]$elements[[1]]
    expect_identical(button$action_id, "invite_mark_sent")
    value <- jsonlite::fromJSON(button$value)
    expect_identical(value$approver, "bob")
    expect_identical(value$record_id, "rec1")
  })
})

describe("airtable_webhook_process", {
  it("does not post when the base is not allowed", {
    posted <- FALSE
    local_mocked_bindings(
      airtable_base_allowed = function(...) FALSE,
      slack_api_call = function(...) {
        posted <<- TRUE
        list(ok = TRUE)
      }
    )
    expect_warning(
      result <- airtable_webhook_process(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1"
      ),
      "Rejected webhook"
    )
    expect_false(result)
    expect_false(posted)
  })

  it("posts the invite-request card when the base is allowed", {
    posted <- NULL
    local_mocked_bindings(
      airtable_base_allowed = function(...) TRUE,
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        posted <<- list(method = method, body = body)
        list(ok = TRUE)
      }
    )
    withr::with_envvar(
      c(SLACK_COMMUNITY_INVITE_CHANNEL = "C_INVITES"),
      {
        result <- airtable_webhook_process(
          email = "ada@example.com",
          name = "Ada",
          chapter = "Oslo",
          record_id = "rec1",
          base_id = "app1",
          table_id = "tbl1"
        )
      }
    )
    expect_true(result)
    expect_identical(posted$method, "chat.postMessage")
    expect_identical(posted$body$channel, "C_INVITES")
    expect_match(posted$body$text, "New Slack invite request", fixed = TRUE)
  })
})

describe("slack_interaction_process", {
  it("posts the approval checklist for invite_approve", {
    posted <- NULL
    local_mocked_bindings(
      slack_response_url_post = function(
        response_url,
        text = NULL,
        blocks = NULL,
        replace_original = FALSE
      ) {
        posted <<- list(
          text = text,
          blocks = blocks,
          replace_original = replace_original
        )
      }
    )
    slack_interaction_process(
      "invite_approve",
      list(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1"
      ),
      "bob",
      "https://hooks.slack.com/r/1"
    )
    expect_true(posted$replace_original)
    expect_match(posted$text, "Approved by @bob", fixed = TRUE)
    expect_true(length(posted$blocks) > 0)
  })

  it("marks the record denied and posts a denial message for invite_deny", {
    update_args <- NULL
    posted <- NULL
    local_mocked_bindings(
      airtable_record_update = function(
        base_id,
        table_id,
        record_id,
        fields,
        ...
      ) {
        update_args <<- list(base_id = base_id, fields = fields)
      },
      slack_response_url_post = function(
        response_url,
        text = NULL,
        blocks = NULL,
        replace_original = FALSE
      ) {
        posted <<- list(text = text, replace_original = replace_original)
      }
    )
    slack_interaction_process(
      "invite_deny",
      list(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1"
      ),
      "bob",
      "https://hooks.slack.com/r/1"
    )
    expect_identical(update_args$fields, list(denied = TRUE))
    expect_match(posted$text, "Denied", fixed = TRUE)
    expect_true(posted$replace_original)
  })

  it("marks the record invited, writes the pending link, and confirms for invite_mark_sent", {
    update_args <- NULL
    put_args <- NULL
    posted <- NULL
    local_mocked_bindings(
      airtable_record_update = function(
        base_id,
        table_id,
        record_id,
        fields,
        ...
      ) {
        update_args <<- list(fields = fields)
      },
      cf_ops_kv_put = function(...) {
        put_args <<- list(...)
        invisible(TRUE)
      },
      slack_response_url_post = function(
        response_url,
        text = NULL,
        blocks = NULL,
        replace_original = FALSE
      ) {
        posted <<- list(text = text, replace_original = replace_original)
      }
    )
    slack_interaction_process(
      "invite_mark_sent",
      list(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1",
        approver = "bob"
      ),
      "carol",
      "https://hooks.slack.com/r/1"
    )
    expect_identical(update_args$fields, list(invited = TRUE))
    expect_identical(put_args$key_name, "pending_link:ada@example.com")
    expect_match(
      posted$text,
      "Invite sent to ada@example.com by @carol",
      fixed = TRUE
    )
    expect_true(posted$replace_original)
  })

  it("posts a failure message when marking sent throws", {
    posted <- NULL
    local_mocked_bindings(
      airtable_record_update = function(...) stop("Airtable is down"),
      slack_response_url_post = function(
        response_url,
        text = NULL,
        blocks = NULL,
        replace_original = FALSE
      ) {
        posted <<- list(text = text, replace_original = replace_original)
      }
    )
    slack_interaction_process(
      "invite_mark_sent",
      list(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1"
      ),
      "carol",
      "https://hooks.slack.com/r/1"
    )
    expect_match(posted$text, "Failed to mark", fixed = TRUE)
    expect_false(posted$replace_original)
  })

  it("still confirms success when only the pending-link write fails", {
    posted <- NULL
    local_mocked_bindings(
      airtable_record_update = function(...) invisible(TRUE),
      cf_ops_kv_put = function(...) stop("KV put unavailable"),
      slack_response_url_post = function(
        response_url,
        text = NULL,
        blocks = NULL,
        replace_original = FALSE
      ) {
        posted <<- list(text = text, replace_original = replace_original)
      }
    )
    expect_warning(
      slack_interaction_process(
        "invite_mark_sent",
        list(
          email = "ada@example.com",
          record_id = "rec1",
          base_id = "app1",
          table_id = "tbl1"
        ),
        "carol",
        "https://hooks.slack.com/r/1"
      ),
      "pending_link write failed"
    )
    expect_match(
      posted$text,
      "Invite sent to ada@example.com by @carol",
      fixed = TRUE
    )
    expect_true(posted$replace_original)
  })

  it("warns and no-ops for an unknown action_id", {
    expect_warning(
      slack_interaction_process(
        "invite_unknown",
        list(),
        "bob",
        "https://hooks.slack.com/r/1"
      ),
      "Unknown interaction"
    )
  })
})
