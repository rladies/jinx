promo_system_prompt <- paste0(
  "You are Jinx, the friendly familiar of RLadies+ - a global organization ",
  "promoting gender diversity in the R community. Jinx uses they/them ",
  "pronouns.\n\n",
  "Write a SHORT, warm invitation (1-2 sentences) spotlighting ONE community ",
  "Slack channel so members will want to join it. You are given the ",
  "channel's name and its description.\n\n",
  "Rules:\n",
  "- 1-2 sentences. Warm and encouraging, with a light touch of cheeky cat ",
  "whimsy (a paw, a whisker, a purr) - sparingly, and never at the cost of ",
  "clarity.\n",
  "- Base it ONLY on the channel name and description provided. Do not invent ",
  "activities, people, events, statistics, or links.\n",
  "- Do NOT write the channel name with a leading '#', and do NOT include any ",
  "links or channel/@ mentions - the message already links the channel above ",
  "your text. Refer to it naturally (\"this channel\", \"here\", \"the folks ",
  "in here\").\n",
  "- Use light Slack markdown (*bold*, _italic_). No preamble, no headers, no ",
  "surrounding quotes - just the invitation text.\n",
  "- Always write the organisation name as *RLadies+* - one word, trailing ",
  "plus, no hyphen.\n",
  "- Speak in the first person (\"I\", \"me\")."
)

promo_recent_key <- function(team_id) {
  glue::glue("promo_recent:{team_id}")
}

promo_skip_channels <- function() {
  raw <- Sys.getenv("SLACK_PROMO_SKIP", "")
  parts <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
  parts[nzchar(parts)]
}

promo_clean_description <- function(text) {
  s <- if (is.null(text) || length(text) == 0L || is.na(text)) "" else text
  s <- gsub("<([^|>]+)\\|([^>]+)>", "\\2", s)
  s <- gsub("<[^>]+>", "", s)
  s <- gsub("https?://\\S+", "", s)
  trimws(gsub("\\s+", " ", s))
}

promo_fallback_blurb <- function(description) {
  glue::glue(
    "_{description}_ \u2014 come and say hi! \U0001F408\u200D\U00002B1B"
  )
}

promo_recent_load <- function(
  team_id,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  raw <- tryCatch(
    cf_ops_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = promo_recent_key(team_id),
      token = api_token
    ),
    error = function(e) NA_character_
  )
  if (length(raw) != 1L || is.na(raw) || !nzchar(raw)) {
    return(character())
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = TRUE),
    error = function(e) character()
  )
  as.character(parsed)
}

promo_recent_save <- function(
  team_id,
  recent,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  cf_ops_kv_put(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = promo_recent_key(team_id),
    value = jsonlite::toJSON(as.character(recent)),
    token = api_token
  )
}

#' Select the community public channels eligible for promotion
#'
#' Keeps non-archived public channels that carry a description (Slack
#' "purpose"), dropping the channel we post the spotlight to and any names in
#' `skip`. The description is what the weekly spotlight is built from, so a
#' channel with an empty purpose has nothing to promote and is left out.
#'
#' @param channels List of Slack channel objects, as returned by
#'   `slack_conversations_list()`.
#' @param target_channel Name of the channel the spotlight is posted to,
#'   excluded so it never promotes itself.
#' @param skip Character vector of additional channel names to exclude.
#' @return A data frame with one row per eligible channel and columns `id`,
#'   `name`, and `description` (cleaned of link markup and URLs).
#' @export
promo_eligible_channels <- function(
  channels,
  target_channel = NULL,
  skip = character()
) {
  empty <- data.frame(
    id = character(),
    name = character(),
    description = character(),
    stringsAsFactors = FALSE
  )
  if (is.null(channels) || length(channels) == 0L) {
    return(empty)
  }

  skip_set <- tolower(c(skip, target_channel))
  rows <- Filter(
    Negate(is.null),
    lapply(channels, promo_channel_row, skip_set = skip_set)
  )
  if (length(rows) == 0L) {
    return(empty)
  }
  do.call(rbind, rows)
}

promo_channel_row <- function(channel, skip_set) {
  id <- channel$id %||% NA_character_
  name <- channel$name %||% NA_character_
  is_droppable <- is.na(id) ||
    is.na(name) ||
    isTRUE(channel$is_archived) ||
    tolower(name) %in% skip_set
  if (is_droppable) {
    return(NULL)
  }
  description <- promo_clean_description(channel$purpose$value %||% "")
  if (!nzchar(description)) {
    return(NULL)
  }
  data.frame(
    id = id,
    name = name,
    description = description,
    stringsAsFactors = FALSE
  )
}

#' Pick the next channel to spotlight, round-robin
#'
#' Chooses the alphabetically-first eligible channel that has not been
#' featured since the cycle began, so every channel gets a turn before any
#' repeats. `recent` is pruned to currently-eligible ids first (channels that
#' were archived or lost their description drop out), and the cycle resets
#' once every eligible channel has been seen.
#'
#' @param eligible Data frame from [promo_eligible_channels()].
#' @param recent Character vector of channel ids featured earlier this cycle.
#' @return `NULL` when nothing is eligible, otherwise a list with `channel`
#'   (the chosen single-row data frame) and `recent` (the updated vector to
#'   persist).
#' @export
promo_pick_channel <- function(eligible, recent = character()) {
  if (is.null(eligible) || nrow(eligible) == 0L) {
    return(NULL)
  }
  recent <- intersect(recent, eligible$id)
  candidates <- eligible[!eligible$id %in% recent, , drop = FALSE]
  if (nrow(candidates) == 0L) {
    recent <- character()
    candidates <- eligible
  }
  chosen <- candidates[order(candidates$name)[1L], , drop = FALSE]
  list(channel = chosen, recent = c(recent, chosen$id))
}

#' Draft a spotlight invitation for a channel in Jinx's voice
#'
#' Calls Workers AI to write a short, warm invitation from the channel's name
#' and description. Failures are swallowed and return `NULL` so the caller can
#' fall back to a plain-description blurb rather than skip the promotion.
#'
#' @param name Channel name (without `#`).
#' @param description Cleaned channel description.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return Character scalar invitation, or `NULL` if the model call failed or
#'   returned nothing usable.
#' @export
promo_blurb <- function(
  name,
  description,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  blurb <- tryCatch(
    cloudflare_generate(
      messages = list(
        list(role = "system", content = promo_system_prompt),
        list(
          role = "user",
          content = glue::glue(
            "Channel name: {name}\nDescription: {description}\n\n",
            "Write the spotlight invitation."
          )
        )
      ),
      account_id = account_id,
      api_token = api_token,
      model = model,
      max_tokens = 160
    ),
    error = function(e) {
      cli::cli_warn("promo_blurb failed: {conditionMessage(e)}")
      NULL
    }
  )
  blurb <- trimws(blurb %||% "")
  if (nzchar(blurb)) blurb else NULL
}

#' Format a channel spotlight as a Slack mrkdwn message
#'
#' Links the featured channel in the header and appends the invitation. The
#' blurb is escaped with `escape_markdown()` before it goes out: a channel's
#' description is user-controlled and flows through the model into a broadcast
#' message, so this neutralises injected links and `<!channel>`/`<!everyone>`
#' mass-pings while leaving `*bold*`/`_italic_` intact.
#'
#' @param id Featured channel id.
#' @param name Featured channel name (without `#`).
#' @param blurb Invitation text from [promo_blurb()] or
#'   `promo_fallback_blurb()`.
#' @return Character scalar Slack mrkdwn message.
#' @export
channel_promo_format <- function(id, name, blurb) {
  glue::glue(
    "\U0001F52E *Channel spotlight:* <#{id}|{name}>\n\n{escape_markdown(blurb)}"
  )
}

#' Build the weekly channel-spotlight message
#'
#' Lists the community workspace's public channels, keeps those with a
#' description, picks the next one round-robin (state stored in KV), and drafts
#' a Jinx-voiced invitation for it - falling back to the plain description if
#' the model call fails.
#'
#' @param team_id Community Slack team id. Defaults to env
#'   `SLACK_COMMUNITY_TEAM_ID`.
#' @param target_channel Channel the spotlight is posted to (and never
#'   promotes). Defaults to env `SLACK_PROMO_CHANNEL`, falling back to
#'   `"general"`.
#' @param skip Additional channel names to exclude. Defaults to the
#'   comma-separated env `SLACK_PROMO_SKIP`.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model used for drafting.
#' @return A list with `text` (the Slack message), `channel_id`,
#'   `channel_name`, and `recent` (the updated round-robin state to persist),
#'   or `NULL` when no channel is eligible.
#' @export
channel_promo_build <- function(
  team_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID"),
  target_channel = Sys.getenv("SLACK_PROMO_CHANNEL", "general"),
  skip = promo_skip_channels(),
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  if (!nzchar(team_id)) {
    cli::cli_abort(
      "team_id is empty; set the {.envvar SLACK_COMMUNITY_TEAM_ID} env var."
    )
  }
  channels <- slack_conversations_list(team_id, "community")
  eligible <- promo_eligible_channels(channels, target_channel, skip)
  if (nrow(eligible) == 0L) {
    return(NULL)
  }

  recent <- promo_recent_load(team_id, namespace_id, account_id, api_token)
  picked <- promo_pick_channel(eligible, recent)
  channel <- picked$channel

  blurb <- promo_blurb(
    channel$name,
    channel$description,
    account_id,
    api_token,
    model
  ) %||%
    promo_fallback_blurb(channel$description)

  list(
    text = channel_promo_format(channel$id, channel$name, blurb),
    channel_id = channel$id,
    channel_name = channel$name,
    recent = picked$recent
  )
}

#' Build and post the weekly channel spotlight to the community workspace
#'
#' Posts one channel's spotlight to the target channel, then records the pick
#' in KV so next week's run features a different channel. The round-robin
#' state is only advanced after a successful post, so a failed run doesn't burn
#' a channel's turn.
#'
#' @inheritParams channel_promo_build
#' @param slack_token Community bot token. Defaults to
#'   [slack_bot_token()] for the community workspace.
#' @return Invisibly, `TRUE` if a spotlight was posted, `FALSE` if there was
#'   nothing eligible to promote.
#' @export
channel_promo_post <- function(
  team_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID"),
  target_channel = Sys.getenv("SLACK_PROMO_CHANNEL", "general"),
  slack_token = slack_bot_token("community"),
  skip = promo_skip_channels(),
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  built <- channel_promo_build(
    team_id = team_id,
    target_channel = target_channel,
    skip = skip,
    namespace_id = namespace_id,
    account_id = account_id,
    api_token = api_token,
    model = model
  )
  if (is.null(built)) {
    cli::cli_alert_info("No channel spotlight to post.")
    return(invisible(FALSE))
  }

  resp <- slack_post_message(
    built$text,
    channel = target_channel,
    token = slack_token
  )
  if (!isTRUE(resp$ok)) {
    cli::cli_abort(
      paste0(
        "Failed to post channel spotlight to #{target_channel}: ",
        "{resp$error %||% 'unknown error'}"
      )
    )
  }

  promo_recent_save(team_id, built$recent, namespace_id, account_id, api_token)
  cli::cli_alert_success(
    "Spotlighted #{built$channel_name} in #{target_channel}"
  )
  invisible(TRUE)
}
