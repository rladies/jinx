#' Commands that anyone may run without global-team authorization
#'
#' Read-only or reply-only actions. Every action *not* listed here is
#' treated as privileged and requires the actor to be a member of the
#' global team directory, so a newly added command defaults to
#' privileged until it is explicitly declared safe.
#'
#' @return Character vector of safe action names.
#' @keywords internal
#' @noRd
safe_commands <- function() {
  c(
    "help",
    "report",
    "report-chapters",
    "analytics",
    "website-analytics",
    "gha-dashboard",
    "contributors-list",
    "contributors-org",
    "events",
    "cfp-list",
    "chapter-health",
    "blog-check-links",
    "translate-status",
    "translate-validate",
    "poll-best",
    "error",
    "unknown"
  )
}

#' Whether a command action requires global-team authorization
#'
#' @param action The `action` field of a parsed command.
#' @return `TRUE` when the action is privileged (default-deny).
#' @keywords internal
#' @noRd
command_is_privileged <- function(action) {
  !isTRUE(action %in% safe_commands())
}

#' Airtable location of the global team member directory
#'
#' The directory is the source of truth for who may run privileged
#' commands. Field names are configurable via `member_directory` in
#' `teams.yml` so the code does not hard-code the Airtable schema.
#'
#' @param config Teams config as returned by [load_teams_config()].
#' @return A list with `base_id`, `table`, `github_field`, `slack_field`.
#' @keywords internal
#' @noRd
member_directory_config <- function(config = NULL) {
  config <- config %||% load_teams_config()
  cfg <- config$member_directory %||% list()
  list(
    base_id = cfg$base_id %||% "appZjaV7eM0Y9FsHZ",
    table = cfg$table %||% "Member",
    github_field = cfg$github_field %||% "GitHub handle",
    slack_field = cfg$slack_field %||% "organiser_slack"
  )
}

#' Normalise a user handle for comparison
#'
#' GitHub logins and Slack usernames are case-insensitive; strip a
#' leading `@` and surrounding whitespace so directory values and
#' request actors compare cleanly.
#'
#' @param x Character vector of handles.
#' @return Lower-cased, `@`-stripped, trimmed handles.
#' @keywords internal
#' @noRd
normalize_handle <- function(x) {
  tolower(sub("^@", "", trimws(x)))
}

#' Whether an actor appears in the global team member directory
#'
#' Looks the actor up in the Airtable member directory, matching the
#' GitHub username column for GitHub-sourced commands and the Slack
#' username column for Slack-sourced commands. Aborts (rather than
#' returning `FALSE`) when the directory cannot be read, so the caller
#' can distinguish "not a member" from "could not verify".
#'
#' @param source Either `"github"` or `"slack"`.
#' @param actor The actor handle (GitHub login or Slack username).
#' @param api_key Airtable API key.
#' @param dir Member directory config from `member_directory_config()`.
#' @return `TRUE` when the actor is in the directory, otherwise `FALSE`.
#' @keywords internal
#' @noRd
gt_actor_is_authorized <- function(
  source,
  actor,
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  dir = member_directory_config()
) {
  if (!is.character(actor) || length(actor) != 1 || !nzchar(trimws(actor))) {
    return(FALSE)
  }
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY is not set; cannot verify authorization.")
  }

  field <- switch(source, github = dir$github_field, slack = dir$slack_field)
  if (is.null(field)) {
    cli::cli_abort("Unknown command source {.val {source}}.")
  }

  records <- airtable_list_records(dir$base_id, dir$table, api_key)
  known <- vapply(
    records,
    function(r) normalize_handle(r$fields[[field]] %||% ""),
    character(1)
  )
  normalize_handle(actor) %in% known[nzchar(known)]
}

#' Authorize a parsed command before execution
#'
#' Privileged commands (anything not in `safe_commands()`) may only be
#' run by members of the global team, identified via the Airtable member
#' directory. Read-only commands are always allowed. The check fails
#' closed: an unknown actor is denied, and a directory lookup error is
#' also denied (with a distinct "try again" message).
#'
#' @param command Parsed command list from [cmd_parse()], or `NULL`.
#' @param actor The requesting actor: a GitHub login when `source` is
#'   `"github"`, or a Slack username when `source` is `"slack"`.
#' @param source Origin of the command, `"github"` or `"slack"`.
#' @param api_key Airtable API key used for the directory lookup.
#' @return A list with `ok` (logical) and `message` (a refusal string
#'   when `ok` is `FALSE`, otherwise `NULL`).
#' @export
cmd_authorize <- function(
  command,
  actor = NULL,
  source = c("github", "slack"),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  source <- match.arg(source)

  if (is.null(command) || !command_is_privileged(command$action)) {
    return(list(ok = TRUE, message = NULL))
  }

  authorized <- tryCatch(
    gt_actor_is_authorized(source, actor %||% "", api_key = api_key),
    error = function(cnd) {
      cli::cli_alert_warning(
        "Authorization check failed: {conditionMessage(cnd)}"
      )
      NA
    }
  )

  if (isTRUE(authorized)) {
    return(list(ok = TRUE, message = NULL))
  }

  message <- if (is.na(authorized)) {
    authz_unverifiable_message()
  } else {
    authz_denied_message(source)
  }
  list(ok = FALSE, message = message)
}

#' @keywords internal
#' @noRd
authz_denied_message <- function(source) {
  handle <- if (source == "slack") "Slack username" else "GitHub username"
  glue::glue(
    "\U0001f6ab This command is limited to the RLadies+ global team. ",
    "If you are a global team member, check that your {handle} is ",
    "recorded in the global team directory."
  )
}

#' @keywords internal
#' @noRd
authz_unverifiable_message <- function() {
  paste0(
    "\U0001f63f I couldn't verify your global-team membership just now. ",
    "Please try again in a moment."
  )
}
