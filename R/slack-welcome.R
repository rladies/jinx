slack_workspaces <- c("community", "organisers")

#' Channels common to both RLadies+ Slack workspaces
#'
#' Channels that exist in both the community and organisers Slack
#' workspaces, and are useful to surface to any new member regardless
#' of which workspace they joined.
#'
#' @return A list of named character vectors with `name` and `desc`.
#' @export
common_welcome_channels <- function() {
  list(
    list(name = "general", desc = "workspace-wide announcements"),
    list(name = "help-r", desc = "ask questions about R and R-related tools"),
    list(
      name = "blogs-by-rladies",
      desc = "a feed of new posts from across the RLadies+ blog network"
    ),
    list(name = "jobs", desc = "job listings shared by the community")
  )
}

#' Default starter channels for the RLadies+ Slack welcome
#'
#' Channel name and short description shown to new members so they
#' have somewhere obvious to head first. The list starts with the
#' channels shared by both workspaces (see [common_welcome_channels()])
#' and then adds workspace-specific extras. Override by passing your
#' own list to [welcome_slack_member()].
#'
#' @param workspace One of `"community"` or `"organisers"`.
#' @return A list of named character vectors with `name` and `desc`.
#' @export
default_welcome_channels <- function(workspace = c("community", "organisers")) {
  workspace <- match.arg(workspace)
  extras <- switch(
    workspace,
    community = list(
      list(
        name = "events_global",
        desc = "global community events, meetups, and conferences"
      ),
      list(name = "career-advice", desc = "career questions and advice"),
      list(
        name = "whereintheworld",
        desc = "find other RLadies+ members in cities you are travelling to"
      ),
      list(name = "random", desc = "off-topic chatter and introductions")
    ),
    organisers = list(
      list(
        name = "help-ask_the_leadership",
        desc = "ask questions to RLadies+ leadership"
      ),
      list(
        name = "online-meetups",
        desc = "chat about online meetups and events"
      ),
      list(
        name = "new-chapters",
        desc = "starting and onboarding new chapters"
      ),
      list(name = "events", desc = "event and conference planning")
    )
  )
  c(common_welcome_channels(), extras)
}

default_welcome_channel <- function(workspace = c("community", "organisers")) {
  workspace <- match.arg(workspace)
  "welcome"
}

default_help_channel <- function(workspace = c("community", "organisers")) {
  workspace <- match.arg(workspace)
  "help-how_to_slack"
}

#' Welcome a new member to an RLadies+ Slack workspace
#'
#' Sends a direct message to the given Slack user introducing them to
#' the workspace, pointing them to the Code of Conduct, the welcome
#' channel, and a starter set of channels to explore. Two templates
#' are available: one for the RLadies+ Community Slack, one for the
#' RLadies+ Organisers Slack.
#'
#' The function is stateless: jinx does not persist any user
#' identifiers. The Slack `team_join` event is the source of truth
#' for who to welcome — see the `slack-welcome.yml` GitHub Actions
#' workflow (`workflow_dispatch` / `repository_dispatch` triggered by
#' the Slack event handler) for the wiring.
#'
#' @param user_id Slack user ID (e.g. `"U12345"`).
#' @param workspace One of `"community"` or `"organisers"`. Selects
#'   which template and default channel set is used.
#' @param coc_url URL to the RLadies+ Code of Conduct.
#' @param welcome_channel Channel name (no `#`) where new members
#'   introduce themselves. Defaults to `"welcome"`.
#' @param help_channel Channel name (no `#`) where workspace questions
#'   can be asked. Workspace-specific default.
#' @param starter_channels List of starter channels, each a list with
#'   `name` and `desc`. Defaults to [default_welcome_channels()] for
#'   the chosen workspace.
#' @param token Slack API token. Defaults to `Sys.getenv("SLACK_TOKEN")`.
#' @return API response (invisibly).
#' @export
welcome_slack_member <- function(
  user_id,
  workspace = c("community", "organisers"),
  coc_url = "https://rladies.org/about/coc/",
  welcome_channel = NULL,
  help_channel = NULL,
  starter_channels = NULL,
  token = Sys.getenv("SLACK_TOKEN")
) {
  workspace <- match.arg(workspace)
  if (!nzchar(token)) {
    cli::cli_abort("SLACK_TOKEN environment variable is not set")
  }
  if (!nzchar(user_id)) {
    cli::cli_abort("`user_id` must be a non-empty Slack user ID")
  }

  welcome_channel <- welcome_channel %||% default_welcome_channel(workspace)
  help_channel <- help_channel %||% default_help_channel(workspace)
  starter_channels <- starter_channels %||% default_welcome_channels(workspace)

  body <- render_slack_welcome(
    user_id = user_id,
    workspace = workspace,
    coc_url = coc_url,
    welcome_channel = welcome_channel,
    help_channel = help_channel,
    starter_channels = starter_channels
  )

  resp <- httr2::request("https://slack.com/api/chat.postMessage") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_body_json(list(
      channel = user_id,
      text = body,
      unfurl_links = FALSE,
      unfurl_media = FALSE
    )) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (isTRUE(resp$ok)) {
    cli::cli_alert_success("Welcomed a new member to the {workspace} Slack")
  } else {
    cli::cli_alert_danger(
      "Failed to welcome new {workspace} Slack member: {resp$error}"
    )
  }

  invisible(resp)
}

render_slack_welcome <- function(
  user_id,
  workspace,
  coc_url,
  welcome_channel,
  help_channel,
  starter_channels
) {
  template <- system.file(
    "templates",
    paste0("slack-welcome-", workspace, ".md"),
    package = "jinx",
    mustWork = TRUE
  )
  template_text <- paste(readLines(template, warn = FALSE), collapse = "\n")

  starter_lines <- vapply(
    starter_channels,
    function(c) {
      sprintf("  - <#%s> — %s", c$name, c$desc)
    },
    character(1)
  )

  glue::glue(
    template_text,
    user_id = user_id,
    coc_url = coc_url,
    welcome_channel = welcome_channel,
    help_channel = help_channel,
    starter_channels = paste(starter_lines, collapse = "\n"),
    .open = "{{",
    .close = "}}"
  )
}
