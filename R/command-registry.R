#' Declare a command's privilege keyword and handler together
#'
#' Every command is registered with a keyword that labels it as
#' `"jinx_safe"` (read-only, anyone may run it) or `"jinx_gated"`
#' (privileged, restricted to the global team). Keeping the keyword next
#' to the handler means a new command is labelled at the point it is
#' defined, and [command_is_privileged()] and [cmd_execute()] both derive
#' from the same registry rather than a separate hand-maintained list.
#'
#' @param keyword Either `"jinx_gated"` (default) or `"jinx_safe"`.
#' @param handler A function of one argument (the parsed command) that
#'   returns the response string.
#' @return A list with `keyword` and `handler`.
#' @keywords internal
#' @noRd
command_spec <- function(keyword = c("jinx_gated", "jinx_safe"), handler) {
  keyword <- match.arg(keyword)
  stopifnot(is.function(handler))
  list(keyword = keyword, handler = handler)
}

#' Registry of jinx commands, keyed by parsed action
#'
#' The single source of truth for command dispatch and privilege. Add a
#' new command here with its keyword and handler; nothing else needs a
#' matching entry.
#'
#' @return A named list of [command_spec()] entries.
#' @keywords internal
#' @noRd
jinx_commands <- function() {
  list(
    help = command_spec("jinx_safe", function(command) read_help_text()),
    invite = command_spec("jinx_gated", function(command) {
      config <- load_teams_config()
      if (command$team %in% team_list_slugs(config)) {
        gt_invite(command$username, command$team)
        glue::glue(
          "Invitation sent to @{command$username}",
          " for the **{command$team}** team."
        )
      } else {
        glue::glue(
          "Unknown team `{command$team}`.",
          " Valid teams: {paste(team_list_slugs(config), collapse = ', ')}"
        )
      }
    }),
    offboard = command_spec("jinx_gated", function(command) {
      config <- load_teams_config()
      if (command$team %in% team_list_slugs(config)) {
        gt_create_offboarding(command$username, command$team)
        glue::glue(
          "Offboarding initiated for @{command$username}",
          " from the **{command$team}** team."
        )
      } else {
        glue::glue(
          "Unknown team `{command$team}`.",
          " Valid teams: {paste(team_list_slugs(config), collapse = ', ')}"
        )
      }
    }),
    "slack-invite" = command_spec("jinx_gated", function(command) {
      slack_invite_request(command$email)
    }),
    report = command_spec("jinx_safe", function(command) {
      report <- report_generate(type = command$type)
      report_format_markdown(report)
    }),
    announce = command_spec("jinx_gated", function(command) {
      glue::glue("Announcing post: {command$url}")
    }),
    "chapter-health" = command_spec("jinx_safe", function(command) {
      chapter_health_summary(chapter_check_health())
    }),
    "blog-add" = command_spec("jinx_gated", function(command) {
      result <- blog_add_pr(command$url)
      if (identical(result$status, "exists")) {
        glue::glue("Blog **{result$filename}** is already listed.")
      } else {
        glue::glue("Blog entry PR created: {result$url}")
      }
    }),
    "blog-check-links" = command_spec("jinx_safe", function(command) {
      blog_links_report(blog_check_links_repo())
    }),
    "chapter-setup" = command_spec("jinx_gated", function(command) {
      url <- chapter_create_setup(
        command$city,
        command$country,
        organizers = character(0)
      )
      glue::glue("Chapter setup issue created: {url}")
    }),
    "chapter-update" = command_spec("jinx_gated", function(command) {
      url <- chapter_create_update(command$city, command$country)
      glue::glue("Chapter update issue created: {url}")
    }),
    "report-chapters" = command_spec("jinx_safe", function(command) {
      health <- chapter_check_health()
      if (nrow(health) == 0) {
        "No chapter data available."
      } else {
        chapter_format_report(health, months = 6)
      }
    }),
    "gha-dashboard" = command_spec("jinx_safe", function(command) {
      data <- gha_generate_dashboard()
      gha_format_dashboard(data)
    }),
    "contributors-list" = command_spec("jinx_safe", function(command) {
      target <- command$repo %||% "jinx"
      contribs <- contributor_list("rladies", target)
      contributor_format(contribs, format = "table")
    }),
    "contributors-update" = command_spec("jinx_gated", function(command) {
      target <- command$repo %||% "jinx"
      url <- contributor_update("rladies", target)
      if (!is.null(url)) {
        glue::glue("Contributors list updated: {url}")
      } else {
        "Contributors list is already up to date."
      }
    }),
    "contributors-org" = command_spec("jinx_safe", function(command) {
      contribs <- contributor_list_org()
      top <- if (nrow(contribs) > 20) contribs[1:20, ] else contribs
      paste0(
        "## Top Contributors (org-wide)\n\n",
        contributor_format(top, format = "table"),
        "\n_Showing top ",
        nrow(top),
        " of ",
        nrow(contribs),
        " total_"
      )
    }),
    events = command_spec("jinx_safe", function(command) {
      events <- event_list_chapter(command$chapter)
      event_create_summary(events, "weekly")
    }),
    "events-sync" = command_spec("jinx_gated", function(command) {
      events <- event_sync_chapters(dry_run = FALSE)
      event_create_summary(events, "weekly")
    }),
    analytics = command_spec("jinx_safe", function(command) {
      data <- analytics_generate_dashboard()
      data$markdown %||% "No analytics data available."
    }),
    "website-analytics" = command_spec("jinx_safe", function(command) {
      data <- website_generate_report(period = command$period)
      data$markdown
    }),
    "cfp-list" = command_spec("jinx_safe", function(command) {
      cfps <- cfp_list_open()
      if (nrow(cfps) == 0) {
        "No open CFPs found."
      } else {
        lines <- glue::glue_data(
          cfps,
          "- **{conference}** (deadline: {deadline}) - {url}"
        )
        paste("## Open CFPs\n", paste(lines, collapse = "\n"))
      }
    }),
    "cfp-add" = command_spec("jinx_gated", function(command) {
      url <- cfp_create_issue(command$conference, command$deadline, command$url)
      glue::glue("CFP issue created: {url}")
    }),
    "cfp-recommend" = command_spec("jinx_gated", function(command) {
      cfp_recommend_speaker(command$conference, command$speaker)
      glue::glue(
        "Speaker recommendation for @{command$speaker}",
        " added to **{command$conference}**."
      )
    }),
    "poll-create" = command_spec("jinx_gated", function(command) {
      created <- meeting_poll_create(
        title = command$title,
        days = command$days,
        from = command$from,
        to = command$to,
        slot = command$slot,
        tz = command$tz,
        kind = command$kind,
        public = command$public
      )
      meeting_poll_format_created(created, command$title)
    }),
    "poll-best" = command_spec("jinx_safe", function(command) {
      poll <- tryCatch(meeting_poll_get(command$id), error = function(e) NULL)
      title <- if (is.list(poll)) poll$title else NULL
      best <- meeting_poll_best(command$id)
      meeting_poll_format_best(best, title = title)
    }),
    "translate-status" = command_spec("jinx_safe", function(command) {
      coverage <- i18n_check_coverage()
      lines <- glue::glue_data(
        coverage,
        paste0(
          "- **{language}**: {translated}/{total_templates}",
          " ({coverage_pct}%)"
        )
      )
      paste("## Translation Coverage\n", paste(lines, collapse = "\n"))
    }),
    "translate-validate" = command_spec("jinx_safe", function(command) {
      results <- i18n_validate_translations(language = command$language)
      issues <- results[results$status != "ok", ]
      if (nrow(issues) == 0) {
        "All translations are valid."
      } else {
        lines <- glue::glue_data(
          issues,
          "- {template} ({language}): {status}"
        )
        paste("## Translation Issues\n", paste(lines, collapse = "\n"))
      }
    }),
    remind = command_spec("jinx_gated", function(command) {
      stale <- gt_remind_stale()
      if (length(stale) == 0) {
        "No stale issues found - all caught up! \U0001f389"
      } else {
        links <- vapply(
          stale,
          function(s) {
            glue::glue("- <{s$url}|{s$title}> ({s$days} days)")
          },
          character(1)
        )
        paste(
          glue::glue("Reminded {length(stale)} stale issue(s):"),
          paste(links, collapse = "\n"),
          sep = "\n"
        )
      }
    }),
    error = command_spec("jinx_safe", function(command) command$message),
    unknown = command_spec("jinx_safe", function(command) {
      glue::glue(
        "Unknown command: `{command$raw}`. Try `/jinx help` for usage."
      )
    })
  )
}

#' Whether a command action requires global-team authorization
#'
#' Reads the action's keyword from [jinx_commands()]. Anything not
#' labelled `"jinx_safe"` - including unregistered or malformed actions -
#' is treated as privileged (default-deny).
#'
#' @param action The `action` field of a parsed command.
#' @return `TRUE` when the action is privileged.
#' @keywords internal
#' @noRd
command_is_privileged <- function(action) {
  if (!is.character(action) || length(action) != 1) {
    return(TRUE)
  }
  spec <- jinx_commands()[[action]]
  !identical(spec$keyword, "jinx_safe")
}
