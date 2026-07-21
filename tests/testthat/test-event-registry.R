describe("event_parse", {
  it("normalizes a recognised kind", {
    payload <- list(
      kind = "team_join",
      team_id = "T_ORG",
      response_url = NULL,
      event = list(user = list(id = "U1"))
    )
    parsed <- event_parse(payload)
    expect_identical(parsed$kind, "team_join")
    expect_identical(parsed$team_id, "T_ORG")
    expect_identical(parsed$event, list(user = list(id = "U1")))
  })

  it("returns kind unknown for an unrecognised kind", {
    parsed <- event_parse(list(kind = "not_a_real_kind", team_id = "T_ORG"))
    expect_identical(parsed$kind, "unknown")
  })

  it("returns kind unknown when kind is missing", {
    parsed <- event_parse(list(team_id = "T_ORG"))
    expect_identical(parsed$kind, "unknown")
  })
})

describe("event_authorize", {
  it("always authorizes airtable_webhook regardless of team_id", {
    result <- event_authorize(list(kind = "airtable_webhook", team_id = NULL))
    expect_true(result$ok)
  })

  it("authorizes team_join from the organiser workspace", {
    result <- event_authorize(
      list(kind = "team_join", team_id = "T_ORG"),
      organiser_id = "T_ORG",
      community_id = "T_COM"
    )
    expect_true(result$ok)
  })

  it("authorizes reaction_added from the community workspace", {
    result <- event_authorize(
      list(kind = "reaction_added", team_id = "T_COM"),
      organiser_id = "T_ORG",
      community_id = "T_COM"
    )
    expect_true(result$ok)
  })

  it("refuses an unrecognised team_id", {
    result <- event_authorize(
      list(kind = "team_join", team_id = "T_OTHER"),
      organiser_id = "T_ORG",
      community_id = "T_COM"
    )
    expect_false(result$ok)
    expect_match(result$message, "not an allowed workspace")
  })

  it("refuses an unknown event kind", {
    result <- event_authorize(list(kind = "unknown"))
    expect_false(result$ok)
  })

  it("refuses a NULL event", {
    result <- event_authorize(NULL)
    expect_false(result$ok)
  })
})

describe("event_execute", {
  it("dispatches team_join to welcome_send", {
    called <- NULL
    local_mocked_bindings(
      welcome_send = function(team_id, user) {
        called <<- list(team_id = team_id, user = user)
        invisible(NULL)
      }
    )
    event_execute(list(
      kind = "team_join",
      team_id = "T_ORG",
      event = list(user = list(id = "U1"))
    ))
    expect_identical(called$team_id, "T_ORG")
    expect_identical(called$user, list(id = "U1"))
  })

  it("dispatches reaction_added to reaction_event_apply", {
    called <- NULL
    local_mocked_bindings(
      reaction_event_apply = function(team_id, event) {
        called <<- list(team_id = team_id, event = event)
      }
    )
    event_execute(list(
      kind = "reaction_added",
      team_id = "T_ORG",
      event = list(reaction = "thumbsup")
    ))
    expect_identical(called$team_id, "T_ORG")
  })

  it("dispatches airtable_webhook to airtable_webhook_process", {
    called <- NULL
    local_mocked_bindings(
      airtable_webhook_process = function(
        email,
        record_id,
        base_id,
        table_id,
        ...
      ) {
        called <<- list(email = email, record_id = record_id)
      }
    )
    event_execute(list(
      kind = "airtable_webhook",
      event = list(
        email = "ada@example.com",
        record_id = "rec1",
        base_id = "app1",
        table_id = "tbl1"
      )
    ))
    expect_identical(called$email, "ada@example.com")
    expect_identical(called$record_id, "rec1")
  })

  it("dispatches slack_interaction to slack_interaction_process", {
    called <- NULL
    local_mocked_bindings(
      slack_interaction_process = function(
        action_id,
        action_data,
        admin_user,
        response_url
      ) {
        called <<- list(
          action_id = action_id,
          admin_user = admin_user,
          response_url = response_url
        )
      }
    )
    event_execute(list(
      kind = "slack_interaction",
      team_id = "T_ORG",
      response_url = "https://hooks.slack.com/r/1",
      event = list(
        action_id = "invite_approve",
        action_data = list(email = "ada@example.com"),
        admin_user = "bob"
      )
    ))
    expect_identical(called$action_id, "invite_approve")
    expect_identical(called$admin_user, "bob")
    expect_identical(called$response_url, "https://hooks.slack.com/r/1")
  })

  it("returns invisibly for a NULL event", {
    expect_null(event_execute(NULL))
  })

  it("returns invisibly for an unknown-kind event", {
    expect_null(event_execute(list(kind = "unknown")))
  })

  it("aborts for a kind with no registered handler", {
    expect_error(
      event_execute(list(kind = "no_such_kind", event = list())),
      "No handler registered"
    )
  })
})
