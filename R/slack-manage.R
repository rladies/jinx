slack_invitees_base_id <- function() {
  Sys.getenv("RLADIES_SLACK_INVITEES_BASE_ID", "appJZFYABfCIdPYMR")
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

#' Subscribe an RSS feed to a Slack channel
#'
#' Posts a `/feed subscribe` command to the specified Slack channel
#' using the Slack API.
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
  if (!nzchar(token)) {
    cli::cli_abort("SLACK_TOKEN environment variable is not set")
  }

  resp <- httr2::request("https://slack.com/api/chat.postMessage") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_body_json(list(
      channel = channel,
      text = paste("/feed subscribe", rss_url)
    )) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (isTRUE(resp$ok)) {
    cli::cli_alert_success("Subscribed {rss_url} to #{channel}")
  } else {
    cli::cli_alert_danger("Failed to subscribe: {resp$error}")
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
