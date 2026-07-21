describe("slack_channel_id_lookup", {
  it("returns NULL for an empty name", {
    expect_null(slack_channel_id_lookup("T_ORG", "", "community"))
  })

  it("uses the cached channel index when present", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) {
        jsonlite::toJSON(list(names = list(general = "C1")), auto_unbox = TRUE)
      },
      slack_conversations_list = function(...) {
        stop("should not be called on a cache hit")
      }
    )
    id <- slack_channel_id_lookup("T_ORG", "general", "community")
    expect_identical(id, "C1")
  })

  it("refreshes the cache from conversations.list on a cache miss", {
    put_args <- NULL
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) stop("not found"),
      slack_conversations_list = function(...) {
        list(list(id = "C1", name = "general"), list(id = "C2", name = "help"))
      },
      cf_ops_kv_put = function(...) {
        put_args <<- list(...)
        invisible(TRUE)
      }
    )
    id <- slack_channel_id_lookup("T_ORG", "help", "community")
    expect_identical(id, "C2")
    expect_identical(put_args$key_name, "channel_index:T_ORG")
  })

  it("returns NULL when conversations.list itself fails", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) stop("not found"),
      slack_conversations_list = function(...) stop("api down")
    )
    expect_warning(
      result <- slack_channel_id_lookup("T_ORG", "general", "community"),
      "conversations.list failed"
    )
    expect_null(result)
  })
})

describe("slack_channel_mention", {
  it("returns a channel mention when the lookup succeeds", {
    local_mocked_bindings(
      slack_channel_id_lookup = function(...) "C1"
    )
    expect_identical(
      slack_channel_mention("T_ORG", "general", "community"),
      "<#C1|general>"
    )
  })

  it("falls back to plain #name text when the lookup fails", {
    local_mocked_bindings(
      slack_channel_id_lookup = function(...) NULL
    )
    expect_identical(
      slack_channel_mention("T_ORG", "general", "community"),
      "#general"
    )
  })
})

describe("slack_conversations_open", {
  it("returns the opened DM channel id", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_identical(method, "conversations.open")
        list(ok = TRUE, channel = list(id = "D1"))
      }
    )
    expect_identical(
      slack_conversations_open("T_ORG", "U1", "community"),
      "D1"
    )
  })
})

describe("pending_link_consume", {
  it("returns NULL for an empty email", {
    expect_null(pending_link_consume(""))
  })

  it("returns and deletes the pending link when present", {
    deleted_key <- NULL
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) {
        jsonlite::toJSON(
          list(email = "ada@example.com", record_id = "rec1"),
          auto_unbox = TRUE
        )
      },
      cf_ops_kv_delete = function(account_id, namespace_id, key_name, token) {
        deleted_key <<- key_name
        invisible(NULL)
      }
    )
    link <- pending_link_consume("Ada@Example.com")
    expect_identical(link$record_id, "rec1")
    expect_identical(deleted_key, "pending_link:ada@example.com")
  })

  it("still returns the link when the cleanup delete fails", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) {
        jsonlite::toJSON(
          list(email = "ada@example.com", record_id = "rec1"),
          auto_unbox = TRUE
        )
      },
      cf_ops_kv_delete = function(...) stop("KV delete unavailable")
    )
    expect_warning(
      link <- pending_link_consume("ada@example.com"),
      "pending_link delete failed"
    )
    expect_identical(link$record_id, "rec1")
  })

  it("returns NULL when nothing is pending", {
    local_mocked_bindings(
      cf_ops_get_kv_value = function(...) stop("not found")
    )
    expect_null(pending_link_consume("ada@example.com"))
  })
})

describe("welcome_message_render", {
  it("renders the community template with resolved channel mentions", {
    local_mocked_bindings(
      channel_index_load = function(...) list(),
      slack_channel_mention = function(
        team_id,
        name,
        workspace,
        channel_index = NULL
      ) {
        paste0("<#", name, ">")
      }
    )
    text <- welcome_message_render("T_COM", "U1", "community")
    expect_match(text, "<@U1>", fixed = TRUE)
    expect_match(text, "<#welcome>", fixed = TRUE)
    expect_match(text, "<#help-how_to_slack>", fixed = TRUE)
    expect_match(text, "help-r", fixed = TRUE)
  })

  it("loads the channel index once and reuses it for every channel mention", {
    load_calls <- 0L
    local_mocked_bindings(
      channel_index_load = function(...) {
        load_calls <<- load_calls + 1L
        list()
      }
    )
    welcome_message_render("T_COM", "U1", "community")
    expect_identical(load_calls, 1L)
  })

  it("renders the organiser template", {
    local_mocked_bindings(
      channel_index_load = function(...) list(),
      slack_channel_mention = function(
        team_id,
        name,
        workspace,
        channel_index = NULL
      ) {
        paste0("<#", name, ">")
      }
    )
    text <- welcome_message_render("T_ORG", "U1", "organiser")
    expect_match(text, "Organisers Slack", fixed = TRUE)
  })

  it("appends the chapter sign-up sparkle line when a link is present", {
    local_mocked_bindings(
      channel_index_load = function(...) list(),
      slack_channel_mention = function(
        team_id,
        name,
        workspace,
        channel_index = NULL
      ) {
        paste0("<#", name, ">")
      }
    )
    text <- welcome_message_render(
      "T_COM",
      "U1",
      "community",
      link = list(record_id = "rec1")
    )
    expect_match(text, "chapter sign-up", fixed = TRUE)
  })

  it("falls back to the plain-text greeting when config can't be read", {
    local_mocked_bindings(
      welcome_config = function() stop("could not read config")
    )
    text <- welcome_message_render("T_COM", "U1", "community")
    expect_match(text, "I'm Jinx", fixed = TRUE)
  })
})

describe("welcome_send", {
  it("does nothing when the event has no user id", {
    called <- FALSE
    local_mocked_bindings(
      slack_conversations_open = function(...) {
        called <<- TRUE
        "D1"
      }
    )
    welcome_send("T_ORG", list())
    expect_false(called)
  })

  it("consumes the pending link, opens a DM, and posts the welcome message", {
    posted <- NULL
    local_mocked_bindings(
      slack_workspace_for_team = function(team_id, ...) "organiser",
      pending_link_consume = function(email) list(record_id = "rec1"),
      slack_conversations_open = function(team_id, user_id, workspace) "D1",
      welcome_message_render = function(
        team_id,
        user_id,
        workspace,
        link = NULL
      ) {
        "hello there"
      },
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        posted <<- list(method = method, body = body)
        list(ok = TRUE)
      }
    )
    welcome_send(
      "T_ORG",
      list(id = "U1", profile = list(email = "ada@example.com"))
    )
    expect_identical(posted$method, "chat.postMessage")
    expect_identical(posted$body$channel, "D1")
    expect_identical(posted$body$text, "hello there")
  })

  it("does not post when the DM fails to open", {
    posted <- FALSE
    local_mocked_bindings(
      slack_workspace_for_team = function(team_id, ...) "organiser",
      pending_link_consume = function(email) NULL,
      slack_conversations_open = function(...) NULL,
      slack_api_call = function(...) {
        posted <<- TRUE
        list(ok = TRUE)
      }
    )
    welcome_send(
      "T_ORG",
      list(id = "U1", profile = list(email = "ada@example.com"))
    )
    expect_false(posted)
  })
})
