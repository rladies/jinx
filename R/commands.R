#' Parse a jinx command from an issue comment
#'
#' Parses commands like:
#' - `/jinx invite @username to website`
#' - `/jinx offboard @username from blog`
#' - `/jinx report weekly`
#' - `/jinx help`
#'
#' @param body Character string, the comment body.
#' @return A named list with `action` and action-specific fields, or `NULL`
#'   if the comment is not a jinx command.
#' @export
parse_command <- function(body) {
  body <- trimws(body)
  if (!startsWith(body, "/jinx ")) {
    return(NULL)
  }

  parts <- strsplit(sub("^/jinx\\s+", "", body), "\\s+")[[1]]
  if (length(parts) == 0) {
    return(NULL)
  }

  parts <- normalize_command(parts)
  action <- tolower(parts[1])

  switch(
    action,
    invite = parse_invite_command(parts),
    offboard = parse_offboard_command(parts),
    announce = parse_announce_command(parts),
    report = parse_report_command(parts),
    remind = list(action = "remind"),
    "validate-directory" = list(action = "validate-directory"),
    "chapter-health" = list(action = "chapter-health"),
    "chapter-setup" = parse_chapter_setup_command(parts),
    "chapter-update" = parse_chapter_update_command(parts),
    "slack-invite" = parse_slack_invite_command(parts),
    "blog-add" = parse_blog_add_command(parts),
    "blog-check-links" = list(action = "blog-check-links"),
    "gha-dashboard" = list(action = "gha-dashboard"),
    contributors = parse_contributors_command(parts),
    events = parse_events_command(parts),
    analytics = list(action = "analytics"),
    "website-analytics" = parse_website_analytics_command(parts),
    cfp = parse_cfp_command(parts),
    translate = parse_translate_command(parts),
    help = list(action = "help"),
    list(action = "unknown", raw = paste(parts, collapse = " "))
  )
}

parse_invite_command <- function(parts) {
  # /jinx invite @username to team
  if (length(parts) < 4 || tolower(parts[3]) != "to") {
    return(list(
      action = "error",
      message = "Usage: `/jinx invite @username to <team>`"
    ))
  }
  list(
    action = "invite",
    username = sub("^@", "", parts[2]),
    team = tolower(parts[4])
  )
}

parse_offboard_command <- function(parts) {
  # /jinx offboard @username from team
  if (length(parts) < 4 || tolower(parts[3]) != "from") {
    return(list(
      action = "error",
      message = "Usage: `/jinx offboard @username from <team>`"
    ))
  }
  list(
    action = "offboard",
    username = sub("^@", "", parts[2]),
    team = tolower(parts[4])
  )
}

parse_slack_invite_command <- function(parts) {
  if (length(parts) != 2 || !nzchar(parts[2])) {
    return(list(
      action = "error",
      message = "Usage: `/jinx slack-invite <email>`"
    ))
  }
  list(action = "slack-invite", email = parts[2])
}

parse_announce_command <- function(parts) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = "Usage: `/jinx announce <post-url>`"
    ))
  }
  list(action = "announce", url = parts[2])
}

parse_blog_add_command <- function(parts) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = "Usage: `/jinx blog-add <url>`"
    ))
  }
  list(action = "blog-add", url = parts[2])
}

parse_report_command <- function(parts) {
  type <- if (length(parts) >= 2) tolower(parts[2]) else "weekly"
  if (type == "chapters") {
    return(list(action = "report-chapters"))
  }
  if (!type %in% c("weekly", "monthly")) {
    return(list(
      action = "error",
      message = "Usage: `/jinx report weekly|monthly|chapters`"
    ))
  }
  list(action = "report", type = type)
}

parse_chapter_setup_command <- function(parts) {
  if (length(parts) < 3) {
    return(list(
      action = "error",
      message = "Usage: `/jinx chapter-setup <city> <country>`"
    ))
  }
  list(
    action = "chapter-setup",
    city = parts[2],
    country = paste(parts[3:length(parts)], collapse = " ")
  )
}

parse_chapter_update_command <- function(parts) {
  if (length(parts) < 3) {
    return(list(
      action = "error",
      message = "Usage: `/jinx chapter-update <city> <country>`"
    ))
  }
  list(
    action = "chapter-update",
    city = parts[2],
    country = paste(parts[3:length(parts)], collapse = " ")
  )
}

parse_events_command <- function(parts) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = "Usage: `/jinx events <chapter>` or `/jinx events sync`"
    ))
  }
  if (tolower(parts[2]) == "sync") {
    return(list(action = "events-sync"))
  }
  list(action = "events", chapter = parts[2])
}

parse_cfp_command <- function(parts) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = "Usage: `/jinx cfp list|add|recommend`"
    ))
  }
  sub_action <- tolower(parts[2])
  switch(
    sub_action,
    list = list(action = "cfp-list"),
    add = {
      if (length(parts) < 5) {
        return(list(
          action = "error",
          message = "Usage: `/jinx cfp add <conference> <deadline> <url>`"
        ))
      }
      list(
        action = "cfp-add",
        conference = parts[3],
        deadline = parts[4],
        url = parts[5]
      )
    },
    recommend = {
      if (length(parts) < 4) {
        return(list(
          action = "error",
          message = "Usage: `/jinx cfp recommend <conference> <speaker>`"
        ))
      }
      list(
        action = "cfp-recommend",
        conference = parts[3],
        speaker = sub("^@", "", parts[4])
      )
    },
    list(
      action = "error",
      message = "Usage: `/jinx cfp list|add|recommend`"
    )
  )
}

parse_website_analytics_command <- function(parts) {
  period <- if (length(parts) >= 2) parts[2] else "30d"
  valid <- c("7d", "30d", "month", "6mo", "12mo")
  if (!period %in% valid) {
    return(list(
      action = "error",
      message = glue::glue(
        "Usage: `/jinx website-analytics [period]`",
        " where period is one of: {paste(valid, collapse = ', ')}"
      )
    ))
  }
  list(action = "website-analytics", period = period)
}

parse_translate_command <- function(parts) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = "Usage: `/jinx translate status|validate <lang>`"
    ))
  }
  sub_action <- tolower(parts[2])
  switch(
    sub_action,
    status = list(action = "translate-status"),
    validate = {
      lang <- if (length(parts) >= 3) parts[3] else NULL
      list(action = "translate-validate", language = lang)
    },
    list(
      action = "error",
      message = "Usage: `/jinx translate status|validate <lang>`"
    )
  )
}

parse_contributors_command <- function(parts) {
  target <- if (length(parts) >= 2) parts[2] else "list"
  if (target == "update") {
    repo <- if (length(parts) >= 3) parts[3] else NULL
    return(list(action = "contributors-update", repo = repo))
  }
  if (target == "org") {
    return(list(action = "contributors-org"))
  }
  list(
    action = "contributors-list",
    repo = if (length(parts) >= 2) parts[2] else NULL
  )
}

#' Execute a parsed jinx command
#'
#' Returns the response message as a character string. The caller is
#' responsible for routing the message to the right destination (GitHub
#' issue comment, Slack, R console, etc.).
#'
#' @param command Parsed command list from [parse_command()].
#' @return Character string with the response message.
#' @export
execute_command <- function(command) {
  if (is.null(command)) {
    return(invisible(NULL))
  }

  switch(
    command$action,
    help = read_help_text(),
    invite = {
      config <- load_teams_config()
      if (command$team %in% team_slugs(config)) {
        gt_invite(command$username, command$team)
        glue::glue(
          "Invitation sent to @{command$username}",
          " for the **{command$team}** team."
        )
      } else {
        glue::glue(
          "Unknown team `{command$team}`.",
          " Valid teams: {paste(team_slugs(config), collapse = ', ')}"
        )
      }
    },
    offboard = {
      config <- load_teams_config()
      if (command$team %in% team_slugs(config)) {
        gt_create_offboarding(command$username, command$team)
        glue::glue(
          "Offboarding initiated for @{command$username}",
          " from the **{command$team}** team."
        )
      } else {
        glue::glue(
          "Unknown team `{command$team}`.",
          " Valid teams: {paste(team_slugs(config), collapse = ', ')}"
        )
      }
    },
    "slack-invite" = {
      send_slack_invite(command$email)
    },
    report = {
      report <- generate_report(type = command$type)
      format_report_markdown(report)
    },
    announce = {
      glue::glue("Announcing post: {command$url}")
    },
    "validate-directory" = "Running directory validation...",
    "chapter-health" = "Checking chapter health...",
    "blog-add" = {
      glue::glue("Creating blog entry for: {command$url}")
    },
    "blog-check-links" = "Checking blog links...",
    "chapter-setup" = {
      url <- create_chapter_setup(
        command$city,
        command$country,
        organizers = character(0)
      )
      glue::glue("Chapter setup issue created: {url}")
    },
    "chapter-update" = {
      url <- create_chapter_update(command$city, command$country)
      glue::glue("Chapter update issue created: {url}")
    },
    "report-chapters" = {
      health <- check_chapter_health()
      if (nrow(health) == 0) {
        "No chapter data available."
      } else {
        format_chapter_report(health, months = 6)
      }
    },
    "gha-dashboard" = {
      data <- generate_gha_dashboard()
      format_gha_dashboard(data)
    },
    "contributors-list" = {
      target <- command$repo %||% "jinx"
      contribs <- list_contributors("rladies", target)
      format_contributors(contribs, format = "table")
    },
    "contributors-update" = {
      target <- command$repo %||% "jinx"
      url <- update_contributors_list("rladies", target)
      if (!is.null(url)) {
        glue::glue("Contributors PR created: {url}")
      } else {
        "Contributors list is already up to date."
      }
    },
    "contributors-org" = {
      contribs <- list_org_contributors()
      top <- if (nrow(contribs) > 20) contribs[1:20, ] else contribs
      paste0(
        "## Top Contributors (org-wide)\n\n",
        format_contributors(top, format = "table"),
        "\n_Showing top ",
        nrow(top),
        " of ",
        nrow(contribs),
        " total_"
      )
    },
    events = {
      events <- list_chapter_events(command$chapter)
      create_event_summary(events, "weekly")
    },
    "events-sync" = {
      events <- sync_chapter_events(dry_run = FALSE)
      summary <- create_event_summary(events, "weekly")
      url <- publish_event_summary(summary)
      glue::glue("Event summary published: {url}")
    },
    analytics = {
      data <- generate_analytics_dashboard()
      data$markdown %||% "No analytics data available."
    },
    "website-analytics" = {
      data <- generate_website_report(period = command$period)
      format_website_analytics(data)
    },
    "cfp-list" = {
      cfps <- list_open_cfps()
      if (nrow(cfps) == 0) {
        "No open CFPs found."
      } else {
        lines <- glue::glue_data(
          cfps,
          "- **{conference}** (deadline: {deadline}) - {url}"
        )
        paste("## Open CFPs\n", paste(lines, collapse = "\n"))
      }
    },
    "cfp-add" = {
      url <- create_cfp_issue(command$conference, command$deadline, command$url)
      glue::glue("CFP issue created: {url}")
    },
    "cfp-recommend" = {
      recommend_speaker(command$conference, command$speaker)
      glue::glue(
        "Speaker recommendation for @{command$speaker}",
        " added to **{command$conference}**."
      )
    },
    "translate-status" = {
      coverage <- check_translation_coverage()
      lines <- glue::glue_data(
        coverage,
        paste0(
          "- **{language}**: {translated}/{total_templates}",
          " ({coverage_pct}%)"
        )
      )
      paste("## Translation Coverage\n", paste(lines, collapse = "\n"))
    },
    "translate-validate" = {
      results <- validate_translations(language = command$language)
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
    },
    remind = {
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
    },
    error = command$message,
    unknown = {
      glue::glue(
        "Unknown command: `{command$raw}`. Try `/jinx help` for usage."
      )
    }
  )
}

normalize_command <- function(parts) {
  phrases <- list(
    list(c("generate", "website", "analytics"), "website-analytics"),
    list(c("website", "analytics"), "website-analytics"),
    list(c("generate", "analytics"), "analytics"),
    list(c("generate", "report"), "report"),
    list(c("generate", "dashboard"), "gha-dashboard"),
    list(c("check", "blog", "links"), "blog-check-links"),
    list(c("check", "chapter", "health"), "chapter-health"),
    list(c("validate", "directory"), "validate-directory"),
    list(c("setup", "chapter"), "chapter-setup"),
    list(c("update", "chapter"), "chapter-update"),
    list(c("add", "blog"), "blog-add"),
    list(c("check", "links"), "blog-check-links"),
    list(c("remind", "stale"), "remind"),
    list(c("slack", "invite"), "slack-invite"),
    list(c("send", "slack", "invite"), "slack-invite")
  )

  lower <- tolower(parts)
  for (phrase in phrases) {
    words <- phrase[[1]]
    action <- phrase[[2]]
    n <- length(words)
    if (length(lower) >= n && identical(lower[seq_len(n)], words)) {
      return(c(action, parts[-seq_len(n)]))
    }
  }
  parts
}

slack_analytics_channel <- function() {
  ch <- Sys.getenv("SLACK_ANALYTICS_CHANNEL", "")
  if (nzchar(ch)) ch else NULL
}

read_help_text <- function() {
  path <- system.file("commands", "help.md", package = "jinx")
  if (!nzchar(path)) {
    return("No help text available.")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
