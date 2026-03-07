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
    "blog-add" = parse_blog_add_command(parts),
    "blog-check-links" = list(action = "blog-check-links"),
    "gha-dashboard" = list(action = "gha-dashboard"),
    contributors = parse_contributors_command(parts),
    events = parse_events_command(parts),
    analytics = list(action = "analytics"),
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
#' @param command Parsed command list from [parse_command()].
#' @param context Named list with `repo` (e.g. "rladies/jinx") and
#'   `issue` (integer issue number).
#' @export
execute_command <- function(command, context) {
  if (is.null(command)) {
    return(invisible())
  }

  owner_repo <- strsplit(context$repo, "/")[[1]]
  owner <- owner_repo[1]
  repo <- owner_repo[2]

  switch(
    command$action,
    help = {
      help_text <- read_help_text()
      post_reply(owner, repo, context$issue, help_text)
    },
    invite = {
      config <- load_teams_config()
      if (!command$team %in% team_slugs(config)) {
        post_reply(
          owner,
          repo,
          context$issue,
          glue::glue(
            "Unknown team `{command$team}`. Valid teams: {paste(team_slugs(config), collapse = ', ')}"
          )
        )
        return(invisible())
      }
      gt_invite(command$username, command$team)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Invitation sent to @{command$username} for the **{command$team}** team."
        )
      )
    },
    offboard = {
      config <- load_teams_config()
      if (!command$team %in% team_slugs(config)) {
        post_reply(
          owner,
          repo,
          context$issue,
          glue::glue(
            "Unknown team `{command$team}`. Valid teams: {paste(team_slugs(config), collapse = ', ')}"
          )
        )
        return(invisible())
      }
      gt_create_offboarding(command$username, command$team)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Offboarding initiated for @{command$username} from the **{command$team}** team."
        )
      )
    },
    report = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Generating **{command$type}** report... I'll post it when ready."
        )
      )
      report <- generate_report(type = command$type)
      publish_report(report)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "**{command$type}** report published."
        )
      )
    },
    announce = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Announcing post: {command$url}"
        )
      )
    },
    "validate-directory" = {
      post_reply(owner, repo, context$issue, "Running directory validation...")
    },
    "chapter-health" = {
      post_reply(owner, repo, context$issue, "Checking chapter health...")
    },
    "blog-add" = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Creating blog entry for: {command$url}"
        )
      )
    },
    "blog-check-links" = {
      post_reply(owner, repo, context$issue, "Checking blog links...")
    },
    "chapter-setup" = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Creating chapter setup issue for **{command$city}, {command$country}**..."
        )
      )
      url <- create_chapter_setup(
        command$city,
        command$country,
        organizers = character(0)
      )
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Chapter setup issue created: {url}"
        )
      )
    },
    "chapter-update" = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Creating chapter update issue for **{command$city}, {command$country}**..."
        )
      )
      url <- create_chapter_update(command$city, command$country)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Chapter update issue created: {url}"
        )
      )
    },
    "report-chapters" = {
      post_reply(
        owner,
        repo,
        context$issue,
        "Generating chapter health report..."
      )
      url <- report_chapter_health()
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Chapter health report published: {url}"
        )
      )
    },
    "gha-dashboard" = {
      post_reply(
        owner,
        repo,
        context$issue,
        "Generating GitHub Actions dashboard..."
      )
      data <- generate_gha_dashboard()
      url <- publish_gha_dashboard(data)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "GHA dashboard published: {url}"
        )
      )
    },
    "contributors-list" = {
      target <- command$repo %||% repo
      contribs <- list_contributors(owner, target)
      body <- format_contributors(contribs, format = "table")
      post_reply(owner, repo, context$issue, body)
    },
    "contributors-update" = {
      target <- command$repo %||% repo
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Updating contributors list for **{target}**..."
        )
      )
      url <- update_contributors_list(owner, target)
      msg <- if (!is.null(url)) {
        glue::glue("Contributors PR created: {url}")
      } else {
        "Contributors list is already up to date."
      }
      post_reply(owner, repo, context$issue, msg)
    },
    "contributors-org" = {
      post_reply(
        owner,
        repo,
        context$issue,
        "Collecting org-wide contributors..."
      )
      contribs <- list_org_contributors()
      top <- if (nrow(contribs) > 20) contribs[1:20, ] else contribs
      body <- paste0(
        "## Top Contributors (org-wide)\n\n",
        format_contributors(top, format = "table"),
        "\n_Showing top ",
        nrow(top),
        " of ",
        nrow(contribs),
        " total_"
      )
      post_reply(owner, repo, context$issue, body)
    },
    events = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Fetching events for **{command$chapter}**..."
        )
      )
      events <- list_chapter_events(command$chapter)
      summary <- create_event_summary(events, "weekly")
      post_reply(owner, repo, context$issue, summary)
    },
    "events-sync" = {
      post_reply(owner, repo, context$issue, "Syncing chapter events...")
      events <- sync_chapter_events(dry_run = FALSE)
      summary <- create_event_summary(events, "weekly")
      url <- publish_event_summary(summary)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Event summary published: {url}"
        )
      )
    },
    analytics = {
      post_reply(
        owner,
        repo,
        context$issue,
        "Generating analytics dashboard..."
      )
      data <- generate_analytics_dashboard()
      url <- publish_analytics_dashboard(data)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Analytics dashboard published: {url}"
        )
      )
    },
    "cfp-list" = {
      cfps <- list_open_cfps()
      if (nrow(cfps) == 0) {
        post_reply(owner, repo, context$issue, "No open CFPs found.")
      } else {
        lines <- vapply(
          seq_len(nrow(cfps)),
          function(i) {
            glue::glue(
              "- **{cfps$conference[i]}** (deadline: {cfps$deadline[i]}) - {cfps$url[i]}"
            )
          },
          character(1)
        )
        post_reply(
          owner,
          repo,
          context$issue,
          paste(
            "## Open CFPs\n",
            paste(lines, collapse = "\n")
          )
        )
      }
    },
    "cfp-add" = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Creating CFP issue for **{command$conference}**..."
        )
      )
      url <- create_cfp_issue(command$conference, command$deadline, command$url)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "CFP issue created: {url}"
        )
      )
    },
    "cfp-recommend" = {
      recommend_speaker(command$conference, command$speaker)
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Speaker recommendation for @{command$speaker} added to **{command$conference}**."
        )
      )
    },
    "translate-status" = {
      coverage <- check_translation_coverage()
      lines <- vapply(
        seq_len(nrow(coverage)),
        function(i) {
          glue::glue(
            "- **{coverage$language[i]}**: {coverage$translated[i]}/{coverage$total_templates[i]} ({coverage$coverage_pct[i]}%)"
          )
        },
        character(1)
      )
      post_reply(
        owner,
        repo,
        context$issue,
        paste(
          "## Translation Coverage\n",
          paste(lines, collapse = "\n")
        )
      )
    },
    "translate-validate" = {
      results <- validate_translations(language = command$language)
      issues <- results[results$status != "ok", ]
      if (nrow(issues) == 0) {
        post_reply(owner, repo, context$issue, "All translations are valid.")
      } else {
        lines <- vapply(
          seq_len(nrow(issues)),
          function(i) {
            glue::glue(
              "- {issues$template[i]} ({issues$language[i]}): {issues$status[i]}"
            )
          },
          character(1)
        )
        post_reply(
          owner,
          repo,
          context$issue,
          paste(
            "## Translation Issues\n",
            paste(lines, collapse = "\n")
          )
        )
      }
    },
    remind = {
      gt_remind_stale()
      post_reply(owner, repo, context$issue, "Stale issue reminders sent.")
    },
    error = {
      post_reply(owner, repo, context$issue, command$message)
    },
    unknown = {
      post_reply(
        owner,
        repo,
        context$issue,
        glue::glue(
          "Unknown command: `{command$raw}`. Try `/jinx help` for usage."
        )
      )
    }
  )

  invisible()
}

read_help_text <- function() {
  path <- system.file("commands", "help.md", package = "jinx")
  if (!nzchar(path)) {
    return("No help text available.")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
