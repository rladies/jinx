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

describe("channel_bookmarks_config", {
  it("reads the bundled bookmarks config", {
    bookmarks <- channel_bookmarks_config()
    expect_true(length(bookmarks) >= 1)
    titles <- vapply(bookmarks, function(b) b$title, character(1))
    expect_true("RLadies+ Guide" %in% titles)
    links <- vapply(bookmarks, function(b) b$link, character(1))
    expect_true(all(startsWith(links, "https://")))
  })
})

describe("slack_conversations_join", {
  it("calls conversations.join with the channel id", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_identical(method, "conversations.join")
        expect_identical(body$channel, "C1")
        list(ok = TRUE)
      }
    )
    result <- slack_conversations_join("T_ORG", "C1", "organiser")
    expect_true(result$ok)
  })
})

describe("slack_conversations_info", {
  it("calls conversations.info with the channel id", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_identical(method, "conversations.info")
        expect_identical(body$channel, "C1")
        list(ok = TRUE, channel = list(is_private = FALSE, is_member = TRUE))
      }
    )
    result <- slack_conversations_info("T_ORG", "C1", "organiser")
    expect_true(result$channel$is_member)
  })
})

describe("slack_bookmarks_list", {
  it("calls bookmarks.list with the channel id", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_identical(method, "bookmarks.list")
        expect_identical(body$channel_id, "C1")
        list(ok = TRUE, bookmarks = list())
      }
    )
    result <- slack_bookmarks_list("T_ORG", "C1", "organiser")
    expect_true(result$ok)
  })
})

describe("slack_bookmarks_add", {
  it("includes the emoji when provided", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_identical(method, "bookmarks.add")
        expect_identical(body$emoji, ":sparkles:")
        list(ok = TRUE)
      }
    )
    slack_bookmarks_add(
      "T_ORG",
      "C1",
      "RLadies+ Guide",
      "https://guide.rladies.org",
      ":sparkles:",
      "organiser"
    )
  })

  it("omits the emoji field when NULL", {
    local_mocked_bindings(
      slack_bot_token = function(workspace) "xoxb-test",
      slack_api_call = function(token, method, body) {
        expect_null(body$emoji)
        list(ok = TRUE)
      }
    )
    slack_bookmarks_add(
      "T_ORG",
      "C1",
      "Title",
      "https://x.example",
      NULL,
      "organiser"
    )
  })
})

describe("setup_channel_ensure_membership", {
  it("joins a public channel it is not a member of", {
    joined <- FALSE
    local_mocked_bindings(
      slack_conversations_info = function(...) {
        list(channel = list(is_private = FALSE, is_member = FALSE))
      },
      slack_conversations_join = function(...) {
        joined <<- TRUE
        list(ok = TRUE)
      }
    )
    result <- setup_channel_ensure_membership("T_ORG", "C1", "organiser")
    expect_true(result$ok)
    expect_true(joined)
  })

  it("does not attempt to join a channel it is already in", {
    joined <- FALSE
    local_mocked_bindings(
      slack_conversations_info = function(...) {
        list(channel = list(is_private = FALSE, is_member = TRUE))
      },
      slack_conversations_join = function(...) {
        joined <<- TRUE
        list(ok = TRUE)
      }
    )
    result <- setup_channel_ensure_membership("T_ORG", "C1", "organiser")
    expect_true(result$ok)
    expect_false(joined)
  })

  it("refuses a private channel it is not a member of", {
    local_mocked_bindings(
      slack_conversations_info = function(...) {
        list(channel = list(is_private = TRUE, is_member = FALSE))
      }
    )
    result <- setup_channel_ensure_membership("T_ORG", "C1", "organiser")
    expect_false(result$ok)
    expect_match(result$message, "private channel")
  })

  it("returns a failure message when conversations.info errors", {
    local_mocked_bindings(
      slack_conversations_info = function(...) stop("HTTP 404")
    )
    result <- setup_channel_ensure_membership("T_ORG", "C1", "organiser")
    expect_false(result$ok)
    expect_match(result$message, "can't quite see")
  })

  it("warns but does not fail when conversations.join errors", {
    local_mocked_bindings(
      slack_conversations_info = function(...) {
        list(channel = list(is_private = FALSE, is_member = FALSE))
      },
      slack_conversations_join = function(...) stop("channel_not_found")
    )
    expect_warning(
      result <- setup_channel_ensure_membership("T_ORG", "C1", "organiser"),
      "conversations.join failed"
    )
    expect_true(result$ok)
  })
})

describe("setup_channel_apply_bookmarks", {
  it("adds bookmarks not already present and skips existing ones", {
    added_titles <- character(0)
    local_mocked_bindings(
      slack_bookmarks_list = function(...) {
        list(bookmarks = list(list(link = "https://guide.rladies.org")))
      },
      slack_bookmarks_add = function(
        team_id,
        channel_id,
        title,
        link,
        emoji,
        workspace
      ) {
        added_titles <<- c(added_titles, title)
        list(ok = TRUE)
      }
    )
    result <- setup_channel_apply_bookmarks("T_ORG", "C1", "organiser")
    expect_true("RLadies+ Guide" %in% result$skipped)
    expect_false("RLadies+ Guide" %in% result$added)
    expect_true(length(result$added) > 0)
    expect_identical(sort(added_titles), sort(result$added))
  })

  it("warns but continues when a bookmark add fails", {
    local_mocked_bindings(
      slack_bookmarks_list = function(...) list(bookmarks = list()),
      slack_bookmarks_add = function(team_id, channel_id, title, ...) {
        if (identical(title, "Code of Conduct")) {
          stop("rate limited")
        }
        list(ok = TRUE)
      }
    )
    expect_warning(
      result <- setup_channel_apply_bookmarks("T_ORG", "C1", "organiser"),
      "Code of Conduct"
    )
    expect_false("Code of Conduct" %in% result$added)
    expect_true("RLadies+ Guide" %in% result$added)
  })
})

describe("setup_channel_process", {
  it("asks the user to run it from within the target channel", {
    result <- setup_channel_process("T_ORG", "", "general")
    expect_match(result, "channel you want to set up")
  })

  it("reports the private-channel refusal message directly", {
    local_mocked_bindings(
      slack_workspace_for_team = function(team_id, ...) "organiser",
      setup_channel_ensure_membership = function(...) {
        list(ok = FALSE, message = "private channel message")
      }
    )
    result <- setup_channel_process("T_ORG", "C1", "general")
    expect_identical(result, "private channel message")
  })

  it("reports added and already-there bookmarks on success", {
    local_mocked_bindings(
      slack_workspace_for_team = function(team_id, ...) "organiser",
      setup_channel_ensure_membership = function(...) {
        list(ok = TRUE, message = NULL)
      },
      setup_channel_apply_bookmarks = function(...) {
        list(added = c("RLadies+ Guide"), skipped = c("Code of Conduct"))
      }
    )
    result <- setup_channel_process("T_ORG", "C1", "general")
    expect_match(result, "#general", fixed = TRUE)
    expect_match(result, "Added.*RLadies\\+ Guide")
    expect_match(result, "Already there.*Code of Conduct")
  })
})
