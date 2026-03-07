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
send_slack_invites <- function(
  invite_link,
  base_id = "appJZFYABfCIdPYMR",
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  sender_name = "R-Ladies Global",
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
    subject = "You are invited to the R-Ladies Community Slack",
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
subscribe_slack_rss <- function(
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
