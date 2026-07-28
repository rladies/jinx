welcome_workspace_key <- function(workspace) {
  if (identical(workspace, "organiser")) "organisers" else "community"
}

welcome_config <- function() {
  path <- system.file("config", "welcome-channels.json", package = "jinx")
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

welcome_message_fallback <- function(user_id, link = NULL) {
  chapter_line <- if (!is.null(link)) {
    paste0(
      "\n\nI matched you up with your RLadies+ chapter sign-up \u2014 ",
      "welcome aboard! \U0001F49C"
    )
  } else {
    ""
  }
  paste0(
    "Hi <@",
    user_id,
    ">! \U0001F52E I'm Jinx (they/them), the RLadies+ community bot.",
    chapter_line,
    "\n\nAsk me anything about RLadies+ \u2014 chapters, events, the guide, ",
    "code of conduct \u2014 and I'll pad off to look it up for you."
  )
}

slack_conversations_list <- function(
  team_id,
  workspace,
  types = "public_channel",
  limit = 1000
) {
  token <- slack_bot_token(workspace)
  channels <- list()
  cursor <- NULL
  repeat {
    body <- list(types = types, limit = limit, exclude_archived = TRUE)
    if (!is.null(cursor)) {
      body$cursor <- cursor
    }
    res <- slack_api_call(token, "conversations.list", body)
    channels <- c(channels, res$channels)
    cursor <- res$response_metadata$next_cursor
    if (is.null(cursor) || !nzchar(cursor)) {
      break
    }
  }
  channels
}

#' Look up a Slack channel's ID by name
#'
#' Caches the workspace's full channel list in KV (`channel_index:{team_id}`,
#' same `SLACK_TOKENS` namespace and 1h TTL the Worker used) to avoid a
#' paginated `conversations.list` call on every lookup. R port of
#' `slack_channel_id_lookup()` from `worker/src/slack-api.js`.
#'
#' @param team_id Slack team id.
#' @param name Channel name (without `#`).
#' @param workspace `"organiser"` or `"community"`.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return The channel ID, or `NULL` if not found.
#' @export
slack_channel_id_lookup <- function(
  team_id,
  name,
  workspace,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  if (is.null(name) || !nzchar(name)) {
    return(NULL)
  }
  names_map <- channel_index_load(
    team_id,
    workspace,
    namespace_id,
    account_id,
    api_token
  )
  names_map[[name]] %||% NULL
}

#' Load (and cache) a workspace's full channel name-to-id index
#'
#' Callers resolving several channel names at once (e.g.
#' [welcome_message_render()]'s starter-channel list) should call this once
#' and look names up in the result, rather than calling
#' [slack_channel_id_lookup()] per name - each call independently checks the
#' KV cache, so looking up N names one-by-one means N redundant KV reads
#' (and N cache-miss races) for data that doesn't change between them.
#'
#' @param team_id Slack team id.
#' @param workspace `"organiser"` or `"community"`.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return A named list mapping channel name to channel id, or `NULL` if
#'   the channel list couldn't be fetched.
#' @export
channel_index_load <- function(
  team_id,
  workspace,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  cache_key <- glue::glue("channel_index:{team_id}")
  index <- tryCatch(
    jsonlite::fromJSON(
      cf_ops_get_kv_value(
        account_id = account_id,
        namespace_id = namespace_id,
        key_name = cache_key,
        token = api_token
      ),
      simplifyVector = FALSE
    ),
    error = function(e) NULL
  )
  if (!is.null(index$names)) {
    return(index$names)
  }

  channels <- tryCatch(
    slack_conversations_list(team_id, workspace),
    error = function(e) {
      cli::cli_warn("conversations.list failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (is.null(channels)) {
    return(NULL)
  }
  names_map <- stats::setNames(
    lapply(channels, function(c) c$id %||% NA_character_),
    vapply(channels, function(c) c$name %||% NA_character_, character(1))
  )
  cf_ops_kv_put(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = cache_key,
    value = jsonlite::toJSON(
      list(
        names = names_map,
        fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      auto_unbox = TRUE
    ),
    ttl_seconds = 3600L,
    token = api_token
  )
  names_map
}

#' Resolve a channel name to a Slack `<#id|name>` mention
#'
#' Falls back to plain `#name` text if the lookup fails - matches the
#' Worker's `channel_mention()` behaviour.
#'
#' @param team_id Slack team id.
#' @param name Channel name (without `#`).
#' @param workspace `"organiser"` or `"community"`.
#' @param channel_index Optional pre-loaded index from
#'   [channel_index_load()], to avoid a redundant KV read when resolving
#'   several channel names in a row.
#' @return Character string mention.
#' @export
slack_channel_mention <- function(
  team_id,
  name,
  workspace,
  channel_index = NULL
) {
  id <- tryCatch(
    if (!is.null(channel_index)) {
      channel_index[[name]] %||% NULL
    } else {
      slack_channel_id_lookup(team_id, name, workspace)
    },
    error = function(e) NULL
  )
  if (!is.null(id)) glue::glue("<#{id}|{name}>") else paste0("#", name)
}

#' Open a Slack direct message channel
#'
#' @param team_id Slack team id.
#' @param user_id Slack user id to DM.
#' @param workspace `"organiser"` or `"community"`.
#' @return The DM channel ID, or `NULL` on failure.
#' @export
slack_conversations_open <- function(team_id, user_id, workspace) {
  token <- slack_bot_token(workspace)
  res <- slack_api_call(token, "conversations.open", list(users = user_id))
  res$channel$id %||% NULL
}

#' Consume a pending chapter sign-up link for a newly joined email
#'
#' Reads and deletes the KV `pending_link:{email}` record (same
#' `SLACK_TOKENS` namespace and key format the Airtable invite flow
#' writes to when marking an invite sent). R port of
#' `slack_pending_link_consume()` from `worker/src/slack-events.js`.
#'
#' @param email Email address to look up.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return The parsed link record, or `NULL` if none was pending.
#' @export
pending_link_consume <- function(
  email,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  if (is.null(email) || !nzchar(email)) {
    return(NULL)
  }
  key <- glue::glue("pending_link:{tolower(trimws(email))}")
  link_raw <- tryCatch(
    cf_ops_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key,
      token = api_token
    ),
    error = function(e) NA_character_
  )
  if (is.na(link_raw) || !nzchar(link_raw)) {
    return(NULL)
  }
  tryCatch(
    cf_ops_kv_delete(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key,
      token = api_token
    ),
    error = function(e) {
      cli::cli_warn("pending_link delete failed: {conditionMessage(e)}")
    }
  )
  jsonlite::fromJSON(link_raw, simplifyVector = FALSE)
}

#' Render a welcome DM for a newly joined Slack member
#'
#' Reads the welcome config and template directly from this package's
#' `inst/` (no GitHub-raw fetch needed - the content already ships here).
#' Falls back to a hardcoded plain-text greeting if either read fails.
#' R port of `welcome_message_render()` from `worker/src/slack-events.js`.
#'
#' @param team_id Slack team id.
#' @param user_id Slack user id of the new member.
#' @param workspace `"organiser"` or `"community"`.
#' @param link Optional pending chapter sign-up link from
#'   [pending_link_consume()].
#' @return Character string with the rendered welcome message.
#' @export
welcome_message_render <- function(team_id, user_id, workspace, link = NULL) {
  cfg <- tryCatch(welcome_config(), error = function(e) NULL)
  workspace_key <- welcome_workspace_key(workspace)
  template_path <- system.file(
    "templates",
    glue::glue("slack-welcome-{workspace_key}.md"),
    package = "jinx"
  )

  if (is.null(cfg) || !nzchar(template_path) || is.null(cfg[[workspace_key]])) {
    return(welcome_message_fallback(user_id, link))
  }

  ws <- cfg[[workspace_key]]
  welcome_channel_name <- ws$welcome_channel %||% "welcome"
  help_channel_name <- ws$help_channel %||% "help-how_to_slack"
  coc_url <- cfg$coc_url %||% "https://rladies.org/about/coc/"
  starter_channels <- rbind(cfg$common, ws$extras)

  channel_index <- channel_index_load(team_id, workspace)

  starter_mentions <- vapply(
    starter_channels$name,
    function(name) {
      slack_channel_mention(team_id, name, workspace, channel_index)
    },
    character(1)
  )
  starter_lines <- paste(
    paste0("  - ", starter_mentions, " \u2014 ", starter_channels$desc),
    collapse = "\n"
  )

  rendered <- render_template(
    template_path,
    list(
      USER_ID = user_id,
      COC_URL = coc_url,
      WELCOME_CHANNEL = slack_channel_mention(
        team_id,
        welcome_channel_name,
        workspace,
        channel_index
      ),
      HELP_CHANNEL = slack_channel_mention(
        team_id,
        help_channel_name,
        workspace,
        channel_index
      ),
      STARTER_CHANNELS = starter_lines
    )
  )

  if (!is.null(link)) {
    rendered <- paste0(
      rendered,
      "\n\n_:sparkles: I matched you up with your RLadies+ chapter ",
      "sign-up \u2014 welcome aboard!_"
    )
  }
  rendered
}

#' Send a welcome DM to a newly joined Slack member
#'
#' The `team_join` event handler registered in `jinx_events()`: consumes
#' any pending chapter sign-up link, opens a DM, renders the welcome
#' message, and posts it. R port of `slack_event_handle_team_join()` from
#' `worker/src/slack-events.js`.
#'
#' @param team_id Slack team id.
#' @param user The event's Slack user object list: `id`, `profile$email`.
#' @return Invisibly, `NULL`.
#' @export
welcome_send <- function(team_id, user) {
  if (is.null(user$id) || !nzchar(user$id)) {
    return(invisible(NULL))
  }
  email <- user$profile$email %||% ""
  link <- pending_link_consume(email)

  workspace <- slack_workspace_for_team(team_id)
  channel_id <- tryCatch(
    slack_conversations_open(team_id, user$id, workspace),
    error = function(e) {
      cli::cli_warn("conversations.open failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (is.null(channel_id)) {
    return(invisible(NULL))
  }

  text <- welcome_message_render(team_id, user$id, workspace, link)
  tryCatch(
    slack_api_call(
      slack_bot_token(workspace),
      "chat.postMessage",
      list(
        channel = channel_id,
        text = text,
        unfurl_links = FALSE,
        unfurl_media = FALSE
      )
    ),
    error = function(e) {
      cli::cli_warn("Welcome DM post failed: {conditionMessage(e)}")
    }
  )
  invisible(NULL)
}

slack_conversations_join <- function(team_id, channel_id, workspace) {
  token <- slack_bot_token(workspace)
  slack_api_call(token, "conversations.join", list(channel = channel_id))
}

slack_conversations_info <- function(team_id, channel_id, workspace) {
  token <- slack_bot_token(workspace)
  slack_api_call(token, "conversations.info", list(channel = channel_id))
}

slack_bookmarks_list <- function(team_id, channel_id, workspace) {
  token <- slack_bot_token(workspace)
  slack_api_call(token, "bookmarks.list", list(channel_id = channel_id))
}

slack_bookmarks_add <- function(
  team_id,
  channel_id,
  title,
  link,
  emoji,
  workspace
) {
  token <- slack_bot_token(workspace)
  body <- list(
    channel_id = channel_id,
    title = title,
    type = "link",
    link = link
  )
  if (!is.null(emoji) && nzchar(emoji)) {
    body$emoji <- emoji
  }
  slack_api_call(token, "bookmarks.add", body)
}

channel_bookmarks_config <- function() {
  path <- system.file("config", "bookmarks.json", package = "jinx")
  cfg <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  Filter(
    function(b) !is.null(b$title) && !is.null(b$link),
    cfg$bookmarks %||% list()
  )
}

setup_channel_ensure_membership <- function(team_id, channel_id, workspace) {
  info <- tryCatch(
    slack_conversations_info(team_id, channel_id, workspace),
    error = function(e) NULL
  )
  if (is.null(info)) {
    return(list(
      ok = FALSE,
      message = glue::glue(
        "I can't quite see into <#{channel_id}> from here."
      )
    ))
  }

  is_private <- isTRUE(info$channel$is_private)
  is_member <- isTRUE(info$channel$is_member)

  if (is_member || !is_private) {
    if (!is_member) {
      tryCatch(
        slack_conversations_join(team_id, channel_id, workspace),
        error = function(e) {
          cli::cli_warn("conversations.join failed: {conditionMessage(e)}")
        }
      )
    }
    return(list(ok = TRUE, message = NULL))
  }

  list(
    ok = FALSE,
    message = paste0(
      "\U0001F408\u200D\U00002B1B I'm not in <#",
      channel_id,
      "> yet (and I can't let myself in \u2014 no thumbs!). Invite me ",
      "first, since it's a private channel, then run ",
      "`/jinx setup-channel` again."
    )
  )
}

setup_channel_apply_bookmarks <- function(team_id, channel_id, workspace) {
  existing <- tryCatch(
    slack_bookmarks_list(team_id, channel_id, workspace),
    error = function(e) list()
  )
  existing_links <- tolower(vapply(
    existing$bookmarks %||% list(),
    function(b) b$link %||% "",
    character(1)
  ))

  added <- character(0)
  skipped <- character(0)
  for (bm in channel_bookmarks_config()) {
    if (tolower(bm$link) %in% existing_links) {
      skipped <- c(skipped, bm$title)
      next
    }
    ok <- tryCatch(
      {
        slack_bookmarks_add(
          team_id,
          channel_id,
          bm$title,
          bm$link,
          bm$emoji,
          workspace
        )
        TRUE
      },
      error = function(e) {
        cli::cli_warn("bookmark {bm$title} failed: {conditionMessage(e)}")
        FALSE
      }
    )
    if (ok) {
      added <- c(added, bm$title)
    }
  }
  list(added = added, skipped = skipped)
}

#' Set up a Slack channel with RLadies+ bookmarks
#'
#' The `"setup-channel"` command handler: joins the channel if needed
#' (public channels only - a private channel requires a human invite
#' first), then adds any bookmarks from `inst/config/bookmarks.json`
#' the channel doesn't already have. R port of `slash_setup_channel()`
#' from the deleted `worker/src/slash-local.js`; reads the bookmarks
#' config directly from this package's `inst/` instead of the Worker's
#' redundant GitHub-raw fetch of the same file.
#'
#' @param team_id Slack team id.
#' @param channel_id Channel to set up.
#' @param channel_name Channel display name, for the reply text.
#' @return Character scalar reply text.
#' @export
setup_channel_process <- function(team_id, channel_id, channel_name) {
  if (is.null(channel_id) || !nzchar(channel_id)) {
    return(paste0(
      "Pop into the channel you want to set up and run this again \u2014 ",
      "I can only tidy the room I'm standing in."
    ))
  }

  workspace <- slack_workspace_for_team(team_id)

  membership <- setup_channel_ensure_membership(team_id, channel_id, workspace)
  if (!membership$ok) {
    return(membership$message)
  }

  bookmarks <- setup_channel_apply_bookmarks(team_id, channel_id, workspace)

  lines <- glue::glue(
    "\U0001F52E Set up *#{channel_name %||% channel_id}* with ",
    "RLadies+ resources."
  )
  if (length(bookmarks$added)) {
    lines <- c(
      lines,
      glue::glue("*Added:* {paste(bookmarks$added, collapse = ', ')}")
    )
  }
  if (length(bookmarks$skipped)) {
    lines <- c(
      lines,
      glue::glue("*Already there:* {paste(bookmarks$skipped, collapse = ', ')}")
    )
  }
  paste(lines, collapse = "\n")
}
