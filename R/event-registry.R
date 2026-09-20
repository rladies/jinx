#' Registry of jinx event handlers, keyed by dispatch kind
#'
#' Companion to [jinx_commands()] for the `slack-event` dispatch type:
#' passive Slack/Airtable events (not user-invoked commands) relayed by
#' the Cloudflare Worker via `repository_dispatch`. Unlike commands,
#' events aren't actor-privilege-gated - they're gated on the originating
#' team being an allowed workspace (see [event_authorize()]) - so there is
#' no keyword wrapper here, just a handler per kind.
#'
#' @return A named list of handler functions, each `function(event)`.
#' @keywords internal
#' @noRd
jinx_events <- function() {
  list(
    team_join = function(event) {
      welcome_send(event$team_id, event$event$user)
    },
    reaction_added = function(event) {
      reaction_event_apply(event$team_id, event$event)
    },
    airtable_webhook = function(event) {
      do.call(airtable_webhook_process, event$event)
    },
    slack_interaction = function(event) {
      slack_interaction_process(
        action_id = event$event$action_id,
        action_data = event$event$action_data,
        admin_user = event$event$admin_user,
        response_url = event$response_url
      )
    }
  )
}

#' Parse a `slack-event` dispatch payload
#'
#' The Worker's `repository_dispatch` payload is already structured JSON
#' (unlike slash commands, which arrive as free text for [cmd_parse()] to
#' split), so this is a thin validator rather than a parser: it confirms
#' `kind` is one of the registered `jinx_events()` entries and normalizes
#' the shape callers can rely on.
#'
#' @param payload A list with `kind`, `team_id`, `response_url`, `event`.
#' @return A list with `kind`, `team_id`, `response_url`, `event`; `kind`
#'   is `"unknown"` when the payload's `kind` isn't registered.
#' @export
event_parse <- function(payload) {
  kind <- payload$kind %||% NA_character_
  if (is.na(kind) || !nzchar(kind) || !(kind %in% names(jinx_events()))) {
    return(list(
      kind = "unknown",
      team_id = NULL,
      response_url = NULL,
      raw = payload
    ))
  }
  list(
    kind = kind,
    team_id = payload$team_id %||% NULL,
    response_url = payload$response_url %||% NULL,
    event = payload$event %||% list()
  )
}

#' Authorize a parsed event before execution
#'
#' Events are gated on the originating team being an allowed workspace,
#' not on actor privilege (there is no "actor" for a passive event like a
#' reaction or a team join - anyone triggers these). `airtable_webhook`
#' events have no `team_id` at all (Airtable webhooks aren't Slack-team
#' scoped) and are trusted by construction: the Worker already verified
#' the webhook's shared secret before dispatching. The other three kinds
#' are checked against the organiser/community team allowlist, mirroring
#' the Worker's own `slack_team_is_allowed()`.
#'
#' @param event Parsed event list from [event_parse()], or `NULL`.
#' @param organiser_id Organiser workspace team id. Defaults to env
#'   `SLACK_ORGANIZER_TEAM_ID`.
#' @param community_id Community workspace team id. Defaults to env
#'   `SLACK_COMMUNITY_TEAM_ID`.
#' @return A list with `ok` (logical) and `message` (a refusal string
#'   when `ok` is `FALSE`, otherwise `NULL`).
#' @export
event_authorize <- function(
  event,
  organiser_id = Sys.getenv("SLACK_ORGANIZER_TEAM_ID"),
  community_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID")
) {
  if (is.null(event) || identical(event$kind, "unknown")) {
    return(list(ok = FALSE, message = "Unknown event kind."))
  }
  if (identical(event$kind, "airtable_webhook")) {
    return(list(ok = TRUE, message = NULL))
  }

  team_id <- event$team_id %||% ""
  allowed <- nzchar(team_id) &&
    ((nzchar(organiser_id) && identical(team_id, organiser_id)) ||
      (nzchar(community_id) && identical(team_id, community_id)))

  if (!allowed) {
    return(list(
      ok = FALSE,
      message = "Event's team_id is not an allowed workspace."
    ))
  }
  list(ok = TRUE, message = NULL)
}

#' Execute a parsed, authorized event
#'
#' Unlike [cmd_execute()], handlers perform their own Slack/Airtable API
#' calls directly rather than returning a reply string for a workflow
#' step to relay - there is no single "response destination" for a
#' passive event the way there is for a command. The return value is a
#' short status string for the GitHub Actions run log only.
#'
#' @param event Parsed event list from [event_parse()].
#' @return Character string describing the outcome, for logging.
#' @export
event_execute <- function(event) {
  if (is.null(event) || identical(event$kind, "unknown")) {
    return(invisible(NULL))
  }
  handler <- jinx_events()[[event$kind]]
  if (is.null(handler)) {
    cli::cli_abort("No handler registered for event kind {.val {event$kind}}.")
  }
  handler(event)
}
