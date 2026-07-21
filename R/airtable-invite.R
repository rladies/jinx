airtable_bases_namespace_id <- function() {
  Sys.getenv("AIRTABLE_BASES_NAMESPACE_ID", "698b7f8a6f214bf9ad9ecfaa839638f4")
}

pending_link_key <- function(email) {
  glue::glue("pending_link:{tolower(trimws(email))}")
}

not_provided <- function(x) {
  if (is.null(x) || !nzchar(x %||% "")) "_not provided_" else x
}

#' Update fields on an Airtable record
#'
#' R's first Airtable write primitive - everything in `R/airtable-sync.R`
#' is read-only. R port of `airtable_record_update()` from the deleted
#' `worker/src/airtable-invite.js`.
#'
#' @param base_id Airtable base ID.
#' @param table_id Airtable table ID.
#' @param record_id Airtable record ID.
#' @param fields Named list of fields to update.
#' @param api_key Airtable API key. Defaults to env `AIRTABLE_API_KEY`.
#' @return Invisibly, `TRUE`.
#' @export
airtable_record_update <- function(
  base_id,
  table_id,
  record_id,
  fields,
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  httr2::request("https://api.airtable.com/v0/") |>
    httr2::req_url_path_append(base_id, table_id, record_id) |>
    httr2::req_method("PATCH") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
    httr2::req_body_json(list(fields = fields)) |>
    httr2::req_perform()
  invisible(TRUE)
}

airtable_meta_bases_fetch <- function(api_key) {
  bases <- character(0)
  offset <- NULL
  repeat {
    req <- httr2::request("https://api.airtable.com/v0/meta/bases") |>
      httr2::req_headers(Authorization = paste("Bearer", api_key))
    if (!is.null(offset)) {
      req <- httr2::req_url_query(req, offset = offset)
    }
    resp <- httr2::req_perform(req) |> httr2::resp_body_json()
    bases <- c(bases, vapply(resp$bases, function(b) b$id, character(1)))
    offset <- resp$offset
    if (is.null(offset)) {
      break
    }
  }
  unique(bases)
}

#' Check whether an Airtable base is within the configured token's scope
#'
#' Caches the allowed-bases list in KV (same `AIRTABLE_BASES` namespace and
#' 1h TTL the Worker used) rather than calling Airtable's Meta API on every
#' webhook. R port of `airtable_base_is_allowed()`/
#' `airtable_allowed_bases_get()` from the deleted
#' `worker/src/airtable-meta.js`.
#'
#' @param base_id Airtable base ID to check.
#' @param namespace_id KV namespace ID for `AIRTABLE_BASES`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param api_key Airtable API key. Defaults to env `AIRTABLE_API_KEY`.
#' @return `TRUE` if the base is within the token's scope.
#' @export
airtable_base_allowed <- function(
  base_id,
  namespace_id = airtable_bases_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  if (is.null(base_id) || !nzchar(base_id)) {
    return(FALSE)
  }
  cached <- tryCatch(
    jsonlite::fromJSON(
      cf_ops_get_kv_value(
        account_id = account_id,
        namespace_id = namespace_id,
        key_name = "allowed_bases",
        token = api_token
      ),
      simplifyVector = FALSE
    ),
    error = function(e) NULL
  )

  bases <- cached$bases
  if (is.null(bases)) {
    fetched <- airtable_meta_bases_fetch(api_key)
    bases <- as.list(fetched)
    cf_ops_kv_put(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = "allowed_bases",
      value = jsonlite::toJSON(
        list(
          bases = fetched,
          fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
        ),
        auto_unbox = TRUE
      ),
      ttl_seconds = 3600L,
      token = api_token
    )
  }
  base_id %in% unlist(bases)
}

#' Build the initial Slack invite-request Block Kit card
#'
#' R port of `slack_invite_request_blocks()` from the deleted
#' `worker/src/airtable-invite.js`. `chapter` is shown but, matching the
#' JS original, deliberately not carried in the button `value` payload.
#'
#' @param email Applicant email.
#' @param name Applicant name, or `NULL`.
#' @param chapter Chapter name, or `NULL`.
#' @param record_id Airtable record ID.
#' @param base_id Airtable base ID.
#' @param table_id Airtable table ID.
#' @return A list of Block Kit blocks.
#' @export
slack_invite_request_blocks <- function(
  email,
  name,
  chapter,
  record_id,
  base_id,
  table_id
) {
  button_value <- jsonlite::toJSON(
    list(
      email = email,
      name = name,
      record_id = record_id,
      base_id = base_id,
      table_id = table_id
    ),
    auto_unbox = TRUE,
    null = "null"
  )

  list(
    list(
      type = "header",
      text = list(
        type = "plain_text",
        text = "\U0001F49C New Slack invite request",
        emoji = TRUE
      )
    ),
    list(
      type = "section",
      fields = list(
        list(
          type = "mrkdwn",
          text = glue::glue("*Name:*\n{not_provided(name)}")
        ),
        list(type = "mrkdwn", text = glue::glue("*Email:*\n{email}")),
        list(
          type = "mrkdwn",
          text = glue::glue("*Chapter:*\n{not_provided(chapter)}")
        ),
        list(
          type = "mrkdwn",
          text = glue::glue("*Airtable ID:*\n`{record_id %||% 'n/a'}`")
        )
      )
    ),
    list(
      type = "actions",
      elements = list(
        list(
          type = "button",
          text = list(
            type = "plain_text",
            text = "\U00002713 Approve",
            emoji = TRUE
          ),
          style = "primary",
          action_id = "invite_approve",
          value = button_value
        ),
        list(
          type = "button",
          text = list(
            type = "plain_text",
            text = "\U00002717 Deny",
            emoji = TRUE
          ),
          style = "danger",
          action_id = "invite_deny",
          value = button_value
        )
      )
    )
  )
}

#' Build the post-approval checklist Block Kit card
#'
#' R port of `slack_invite_approval_checklist_blocks()` from the deleted
#' `worker/src/airtable-invite.js`.
#'
#' @param email Applicant email.
#' @param approver Slack username who approved the request.
#' @param record_id Airtable record ID.
#' @param base_id Airtable base ID.
#' @param table_id Airtable table ID.
#' @return A list of Block Kit blocks.
#' @export
slack_invite_approval_checklist_blocks <- function(
  email,
  approver,
  record_id,
  base_id,
  table_id
) {
  list(
    list(
      type = "header",
      text = list(
        type = "plain_text",
        text = "\U00002705 Approved \U00002014 invite this person",
        emoji = TRUE
      )
    ),
    list(
      type = "section",
      text = list(
        type = "mrkdwn",
        text = glue::glue(
          "Approved by *@{approver}*. Send the invite manually:\n\n",
          "  1. Open the workspace menu (top-left).\n",
          "  2. Choose *Invite people to RLadies+*.\n",
          "  3. Paste this email and send:"
        )
      )
    ),
    list(
      type = "section",
      text = list(type = "mrkdwn", text = glue::glue("`{email}`"))
    ),
    list(
      type = "actions",
      elements = list(list(
        type = "button",
        text = list(
          type = "plain_text",
          text = "\U00002713 Mark invite sent",
          emoji = TRUE
        ),
        style = "primary",
        action_id = "invite_mark_sent",
        value = jsonlite::toJSON(
          list(
            email = email,
            record_id = record_id,
            approver = approver,
            base_id = base_id,
            table_id = table_id
          ),
          auto_unbox = TRUE,
          null = "null"
        )
      ))
    ),
    list(
      type = "context",
      elements = list(list(
        type = "mrkdwn",
        text = paste0(
          "Click *Mark invite sent* once the invite has been delivered ",
          "\U00002014 that flips the Airtable record."
        )
      ))
    )
  )
}

#' Process an Airtable invite-request webhook
#'
#' The `airtable_webhook` event handler registered in `jinx_events()`.
#' Checks the base is within the configured Airtable token's scope, builds
#' the approval-request card, and posts it to the community-invite
#' channel. R port of the remainder of `airtable_webhook_handle()` (after
#' shared-secret verification, which stays in the Worker) from the
#' deleted `worker/src/airtable-invite.js`.
#'
#' @param email Applicant email.
#' @param name Applicant name, or `NULL`.
#' @param chapter Chapter name, or `NULL`.
#' @param record_id Airtable record ID.
#' @param base_id Airtable base ID.
#' @param table_id Airtable table ID.
#' @param channel Slack channel to post the request to. Defaults to env
#'   `SLACK_COMMUNITY_INVITE_CHANNEL`.
#' @return Invisibly, `TRUE` if posted, `FALSE` if the base was rejected.
#' @export
airtable_webhook_process <- function(
  email,
  name = NULL,
  chapter = NULL,
  record_id,
  base_id,
  table_id,
  channel = Sys.getenv("SLACK_COMMUNITY_INVITE_CHANNEL")
) {
  if (!airtable_base_allowed(base_id)) {
    cli::cli_warn("Rejected webhook from unknown base {base_id}")
    return(invisible(FALSE))
  }

  blocks <- slack_invite_request_blocks(
    email,
    name,
    chapter,
    record_id,
    base_id,
    table_id
  )
  slack_api_call(
    slack_bot_token("community"),
    "chat.postMessage",
    list(
      channel = channel,
      text = glue::glue("New Slack invite request from {name %||% email}"),
      blocks = blocks
    )
  )
  invisible(TRUE)
}

slack_interaction_approve <- function(data, approver, response_url) {
  slack_response_url_post(
    response_url,
    text = glue::glue("Approved by @{approver} - invite {data$email} manually"),
    blocks = slack_invite_approval_checklist_blocks(
      email = data$email,
      approver = approver,
      record_id = data$record_id,
      base_id = data$base_id,
      table_id = data$table_id
    ),
    replace_original = TRUE
  )
}

slack_interaction_deny <- function(data, admin_user, response_url) {
  if (
    !is.null(data$record_id) &&
      !is.null(data$base_id) &&
      !is.null(data$table_id)
  ) {
    tryCatch(
      airtable_record_update(
        data$base_id,
        data$table_id,
        data$record_id,
        list(denied = TRUE)
      ),
      error = function(e) {
        cli::cli_warn("Airtable update failed: {conditionMessage(e)}")
      }
    )
  }
  slack_response_url_post(
    response_url,
    text = glue::glue(
      "\U0000274C *Denied* by @{admin_user} \U00002014 {data$email} will not be invited"
    ),
    replace_original = TRUE
  )
}

slack_interaction_mark_sent <- function(data, sender, response_url) {
  result <- tryCatch(
    {
      if (
        !is.null(data$record_id) &&
          !is.null(data$base_id) &&
          !is.null(data$table_id)
      ) {
        airtable_record_update(
          data$base_id,
          data$table_id,
          data$record_id,
          list(invited = TRUE)
        )
      }
      if (!is.null(data$email)) {
        tryCatch(
          cf_ops_kv_put(
            namespace_id = slack_tokens_namespace_id(),
            key_name = pending_link_key(data$email),
            value = jsonlite::toJSON(
              list(
                email = data$email,
                record_id = data$record_id %||% NA,
                base_id = data$base_id %||% NA,
                table_id = data$table_id %||% NA,
                approver = data$approver %||% NA,
                marked_sent_by = sender,
                marked_sent_at = format(
                  Sys.time(),
                  "%Y-%m-%dT%H:%M:%SZ",
                  tz = "UTC"
                )
              ),
              auto_unbox = TRUE,
              na = "null"
            ),
            ttl_seconds = 90L * 24L * 60L * 60L
          ),
          error = function(e) {
            cli::cli_warn("pending_link write failed: {conditionMessage(e)}")
          }
        )
      }
      NULL
    },
    error = function(e) e
  )

  if (is.null(result)) {
    approver_line <- if (!is.null(data$approver)) {
      glue::glue(" \U00002014 approved by @{data$approver}")
    } else {
      ""
    }
    slack_response_url_post(
      response_url,
      text = glue::glue(
        "\U00002705 Invite sent to {data$email} by @{sender}{approver_line}"
      ),
      replace_original = TRUE
    )
  } else {
    slack_response_url_post(
      response_url,
      text = glue::glue(
        "\U0001F63F Failed to mark {data$email} as invited in Airtable: {conditionMessage(result)}"
      ),
      replace_original = FALSE
    )
  }
}

#' Process a Slack interaction from the invite-approval flow
#'
#' The `slack_interaction` event handler registered in `jinx_events()`.
#' Branches on `action_id` exactly like the three JS functions it replaces
#' (`slack_invite_process_approval`/`_sent`/`_denial`, deleted from
#' `worker/src/airtable-invite.js`), replying via `response_url` for each.
#'
#' @param action_id One of `"invite_approve"`, `"invite_deny"`,
#'   `"invite_mark_sent"`.
#' @param action_data Parsed button `value` payload: `email`, `record_id`,
#'   `base_id`, `table_id`, and (for approve replies) `approver`.
#' @param admin_user Slack username who clicked the button.
#' @param response_url The interaction's `response_url`.
#' @return Invisibly, `NULL`.
#' @export
slack_interaction_process <- function(
  action_id,
  action_data,
  admin_user,
  response_url
) {
  switch(
    action_id,
    invite_approve = slack_interaction_approve(
      action_data,
      admin_user,
      response_url
    ),
    invite_deny = slack_interaction_deny(action_data, admin_user, response_url),
    invite_mark_sent = slack_interaction_mark_sent(
      action_data,
      admin_user,
      response_url
    ),
    cli::cli_warn("Unknown interaction action_id: {action_id}")
  )
  invisible(NULL)
}
