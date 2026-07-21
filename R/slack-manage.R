slack_invitees_base_id <- function() {
  Sys.getenv("RLADIES_SLACK_INVITEES_BASE_ID", "appJZFYABfCIdPYMR")
}

#' KV namespace ID for the `SLACK_TOKENS` namespace
#'
#' Matches `wrangler.jsonc`'s `SLACK_TOKENS` binding - shared by the
#' worker's OAuth-token store, channel-index cache, pending-link records,
#' and reaction-feedback tallies, all overloaded onto one namespace.
#'
#' @return The namespace ID string.
#' @keywords internal
#' @noRd
slack_tokens_namespace_id <- function() {
  Sys.getenv("SLACK_TOKENS_NAMESPACE_ID", "5614aacb7982413e807c2ae2126a4b3b")
}

#' Send pending Slack invitations
#'
#' Fetches pending invitees from Airtable and prepares invite emails
#' with a Slack invitation link.
#'
#' @param invite_link Active Slack invite URL (valid for 30 days).
#' @param base_id Airtable base ID for Slack invitees.
#' @param api_key Airtable API key.
#' @param sender_name Name of the sender.
#' @param sender_email Sender email address.
#' @param dry_run If `TRUE` (default), only returns prepared emails.
#' @return Data frame of prepared emails (invisibly).
#' @export
slack_invite_batch <- function(
  invite_link,
  base_id = slack_invitees_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  sender_name = "RLadies+ Global",
  sender_email = "info@rladies.org",
  dry_run = TRUE
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }

  records <- airtable_list_records(base_id, "Table 1", api_key)

  invitees <- lapply(records, function(r) {
    list(
      id = r$id,
      email = r$fields$email %||% "",
      invited = isTRUE(r$fields$invited)
    )
  })

  pending <- Filter(function(x) nzchar(x$email) && !x$invited, invitees)

  if (length(pending) == 0) {
    cli::cli_alert_info("No pending Slack invitations")
    return(invisible(data.frame()))
  }

  template <- system.file("templates", "slack-invite.md", package = "jinx")
  template_text <- paste(readLines(template, warn = FALSE), collapse = "\n")

  expire_date <- format(Sys.Date() + 30, "%B %d, %Y")

  emails <- data.frame(
    email = vapply(pending, function(x) x$email, character(1)),
    subject = "You are invited to the RLadies+ Community Slack",
    stringsAsFactors = FALSE
  )

  emails$body <- vapply(
    seq_len(nrow(emails)),
    function(i) {
      glue::glue(
        template_text,
        link = invite_link,
        date = expire_date,
        sender = sender_name,
        .open = "{{",
        .close = "}}"
      )
    },
    character(1)
  )

  if (dry_run) {
    cli::cli_alert_info("Dry run: {nrow(emails)} invite emails prepared")
  } else {
    cli::cli_alert_success("{nrow(emails)} Slack invitations sent")
  }

  invisible(emails)
}

#' Request a Slack invitation for someone not yet on the workspace
#'
#' The bot cannot invite users directly (Slack admin scopes are not
#' available to community apps). Instead, this function posts a
#' message to an organisers' Slack channel with the email address and
#' instructions for a workspace admin to action the invite manually,
#' then flips the matching Airtable record's `invited` flag for audit.
#'
#' @param email Email address to request an invite for.
#' @param channel Slack channel where the request is posted. Defaults
#'   to `SLACK_INVITE_REQUEST_CHANNEL` env var, falling back to
#'   `"global-team"`.
#' @param base_id Airtable base ID for Slack invitees.
#' @param api_key Airtable API key. If unset, the Airtable audit step
#'   is skipped.
#' @param token Slack bot token (`chat:write` scope is enough).
#' @return A single status string suitable for posting back as a PR
#'   comment.
#' @export
slack_invite_request <- function(
  email,
  channel = Sys.getenv("SLACK_INVITE_REQUEST_CHANNEL"),
  base_id = slack_invitees_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  token = Sys.getenv("SLACK_TOKEN")
) {
  if (!nzchar(channel)) {
    channel <- "global-team"
  }

  if (!nzchar(token)) {
    cli::cli_abort(
      "SLACK_TOKEN environment variable is not set; cannot post invite request."
    )
  }

  if (!is_valid_email(email)) {
    return(glue::glue("Invalid email address: `{email}`"))
  }

  text <- review_invite_message(email)
  resp <- slack_post_message(text, channel, token)

  if (!isTRUE(resp$ok)) {
    cli::cli_abort(c(
      "Could not post invite request to #{channel}.",
      i = "Slack API error: {resp$error %||% 'unknown'}"
    ))
  }

  if (nzchar(api_key)) {
    airtable_mark_invited(email, base_id, api_key)
  }

  glue::glue(
    "Invite request for {email} posted to #{channel}; an admin will action it."
  )
}

is_valid_email <- function(email) {
  isTRUE(grepl(
    "^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$",
    email
  ))
}

review_invite_message <- function(email) {
  glue::glue(
    ":wave: *Slack invite requested* for `{email}`.\n",
    "An admin needs to send the invite:\n",
    " 1. Open the workspace menu (RLadies+ name, top-left).\n",
    " 2. Choose *Invite people to RLadies+*.\n",
    " 3. Paste the email above and send.\n",
    "Once sent, react with :white_check_mark: so we know it's done.",
    .trim = FALSE
  )
}

airtable_mark_invited <- function(
  email,
  base_id = slack_invitees_base_id(),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  records <- airtable_list_records(base_id, "Table 1", api_key)
  match <- Filter(
    function(r) identical(r$fields$email, email),
    records
  )
  if (length(match) == 0) {
    cli::cli_alert_warning("No Airtable record found for {email}")
    return(FALSE)
  }

  record_id <- match[[1]]$id
  httr2::request(
    glue::glue("https://api.airtable.com/v0/{base_id}/Table%201/{record_id}")
  ) |>
    httr2::req_method("PATCH") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
    httr2::req_body_json(list(fields = list(invited = TRUE))) |>
    httr2::req_perform()

  cli::cli_alert_success("Airtable record {record_id} marked as invited")
  TRUE
}

#' Post a request to subscribe an RSS feed to a Slack channel
#'
#' Slack only runs slash commands typed by a real user, so a bot cannot
#' subscribe a feed directly. This posts an actionable request asking a
#' human in the channel to run `/feed subscribe <url>`.
#'
#' @param rss_url RSS feed URL to subscribe.
#' @param channel Slack channel name (without #). Defaults to "rladiesblogs".
#' @param token Slack API token.
#' @return API response (invisibly).
#' @export
slack_subscribe_rss <- function(
  rss_url,
  channel = "rladiesblogs",
  token = Sys.getenv("SLACK_TOKEN")
) {
  text <- glue::glue(
    ":inbox_tray: *RSS feed to subscribe* in #{channel}.\n",
    "The Slack RSS app only responds to a real user, so please run:\n",
    "`/feed subscribe {rss_url}`",
    .trim = FALSE
  )

  resp <- slack_post_message(text, channel, token)

  if (isTRUE(resp$ok)) {
    cli::cli_alert_success("Posted RSS subscribe request for {rss_url}")
  }

  invisible(resp)
}

#' Post a message to a Slack channel
#'
#' Sends a markdown-formatted message to the specified Slack channel
#' using the Slack Web API.
#'
#' @param text Message text (supports Slack mrkdwn formatting).
#' @param channel Slack channel name (without #).
#' @param token Slack API token. Defaults to `Sys.getenv("SLACK_TOKEN")`.
#' @return API response (invisibly).
#' @export
slack_post_message <- function(
  text,
  channel,
  token = Sys.getenv("SLACK_TOKEN")
) {
  if (!nzchar(token)) {
    cli::cli_abort("SLACK_TOKEN environment variable is not set")
  }

  resp <- httr2::request("https://slack.com/api/chat.postMessage") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_body_json(list(
      channel = channel,
      text = text,
      unfurl_links = FALSE
    )) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (isTRUE(resp$ok)) {
    cli::cli_alert_success("Message posted to #{channel}")
  } else {
    cli::cli_alert_danger("Failed to post to #{channel}: {resp$error}")
  }

  invisible(resp)
}

#' Call a Slack Web API method
#'
#' Generic low-level Slack API caller shared by the event/command
#' handlers that need more than [slack_post_message()]'s single
#' `chat.postMessage` call - DM opening, channel lookup, bookmarks, and
#' so on. Retries once on a 429 or 5xx response, honouring the
#' `Retry-After` header (capped at 5s), mirroring
#' `worker/src/slack-api.js`'s `slack_api_call()`.
#'
#' @param token Slack bot token.
#' @param method Slack Web API method name, e.g. `"conversations.open"`.
#' @param body Named list of request parameters.
#' @return The parsed JSON response (a list).
#' @export
slack_api_call <- function(token, method, body = list()) {
  if (!nzchar(token)) {
    cli::cli_abort("Slack token is not set.")
  }

  resp <- httr2::request(paste0("https://slack.com/api/", method)) |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_body_json(body) |>
    httr2::req_retry(
      max_tries = 2,
      is_transient = function(resp) {
        httr2::resp_status(resp) == 429 || httr2::resp_status(resp) >= 500
      },
      after = function(resp) {
        min(as.numeric(httr2::resp_header(resp, "Retry-After") %||% 1), 5)
      }
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (!isTRUE(resp$ok)) {
    cli::cli_abort("Slack API {method} failed: {resp$error %||% 'unknown'}")
  }
  resp
}

#' Resolve the bot token for a jinx-operated Slack workspace
#'
#' R/GitHub Actions only ever operates in two known workspaces
#' (organiser, community) via two static secrets, unlike the Worker's
#' per-team OAuth-token KV store which supports arbitrary installs - jinx
#' isn't installed anywhere else, so the simpler static lookup is enough.
#'
#' @param workspace Either `"organiser"` or `"community"`.
#' @return The bot token string.
#' @export
slack_bot_token <- function(workspace = c("organiser", "community")) {
  workspace <- match.arg(workspace)
  token <- if (workspace == "organiser") {
    Sys.getenv("SLACK_ORGANISER_TOKEN")
  } else {
    Sys.getenv("SLACK_COMMUNITY_TOKEN")
  }
  if (!nzchar(token)) {
    cli::cli_abort("No Slack bot token set for the {workspace} workspace.")
  }
  token
}

#' Map a Slack team id to its workspace name
#'
#' @param team_id Slack team id from an event/command payload.
#' @param organiser_id Organiser workspace team id. Defaults to env
#'   `SLACK_ORGANIZER_TEAM_ID`.
#' @param community_id Community workspace team id. Defaults to env
#'   `SLACK_COMMUNITY_TEAM_ID`.
#' @return `"organiser"` or `"community"`.
#' @export
slack_workspace_for_team <- function(
  team_id,
  organiser_id = Sys.getenv("SLACK_ORGANIZER_TEAM_ID"),
  community_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID")
) {
  if (nzchar(organiser_id) && identical(team_id, organiser_id)) {
    return("organiser")
  }
  if (nzchar(community_id) && identical(team_id, community_id)) {
    return("community")
  }
  cli::cli_abort("team_id {.val {team_id}} is not a recognised workspace.")
}

#' Reply to a Slack interaction via its `response_url`
#'
#' Posts directly from R rather than relying on a GitHub Actions workflow
#' step to curl the reply - keeps the reply logic testable and in one
#' language. Slack's `response_url` accepts a message replacement for up
#' to 30 minutes after the original interaction.
#'
#' @param response_url The `response_url` from a Slack interaction payload.
#' @param text Fallback plain text (shown if `blocks` can't render).
#' @param blocks Block Kit blocks list, or `NULL`.
#' @param replace_original Whether to replace the original message.
#' @return The raw response body (invisibly).
#' @export
slack_response_url_post <- function(
  response_url,
  text = NULL,
  blocks = NULL,
  replace_original = FALSE
) {
  if (!grepl("^https://hooks\\.slack\\.com/", response_url)) {
    cli::cli_abort(
      "Refusing to post to a response_url that isn't a hooks.slack.com URL."
    )
  }
  body <- list(replace_original = replace_original)
  if (!is.null(text)) {
    body$text <- text
  }
  if (!is.null(blocks)) {
    body$blocks <- blocks
  }

  resp <- httr2::request(response_url) |>
    httr2::req_body_json(body) |>
    httr2::req_perform() |>
    httr2::resp_body_string()

  invisible(resp)
}
