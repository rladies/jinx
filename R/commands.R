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
cmd_parse <- function(body) {
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
    questions = parse_questions_command(parts),
    cfp = parse_cfp_command(parts),
    poll = parse_poll_command(parts),
    translate = parse_translate_command(parts),
    review = parse_review_command(parts),
    "brand-check" = parse_review_alias(parts, "brand"),
    "blog-review" = parse_review_alias(parts, "blog"),
    "social-review" = parse_review_alias(parts, "social"),
    "translate-review" = parse_review_alias(parts, "translation"),
    "copilot-sync" = parse_copilot_sync_command(parts),
    help = list(action = "help"),
    list(action = "unknown", raw = paste(parts, collapse = " "))
  )
}

parse_review_command <- function(parts) {
  gates <- copilot_gates()
  usage <- glue::glue(
    "Usage: `/jinx review {paste(gates, collapse = '|')} <pr>`"
  )
  if (length(parts) < 3) {
    return(list(action = "error", message = usage))
  }
  gate <- tolower(parts[2])
  if (!gate %in% gates) {
    return(list(action = "error", message = usage))
  }
  list(action = "review", gate = gate, pr = parts[3])
}

parse_review_alias <- function(parts, gate) {
  if (length(parts) < 2) {
    return(list(
      action = "error",
      message = glue::glue("Usage: `/jinx {parts[1]} <pr>`")
    ))
  }
  list(action = "review", gate = gate, pr = parts[2])
}

parse_copilot_sync_command <- function(parts) {
  usage <- "Usage: `/jinx copilot-sync <owner/repo>`"
  if (length(parts) < 2 || !nzchar(parts[2])) {
    return(list(action = "error", message = usage))
  }
  if (grepl("/", parts[2], fixed = TRUE)) {
    segments <- strsplit(parts[2], "/", fixed = TRUE)[[1]]
    if (length(segments) != 2 || !all(nzchar(segments))) {
      return(list(action = "error", message = usage))
    }
    return(list(
      action = "copilot-sync",
      owner = segments[1],
      repo = segments[2]
    ))
  }
  list(action = "copilot-sync", owner = "rladies", repo = parts[2])
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

parse_poll_command <- function(parts) {
  usage <- paste(
    "Usage: `/jinx poll create <title> days=<d1,d2> from=HH:MM",
    "to=HH:MM slot=<min> [tz=<zone>]` or `/jinx poll best <id>`"
  )
  if (length(parts) < 2) {
    return(list(action = "error", message = usage))
  }
  sub_action <- tolower(parts[2])
  switch(
    sub_action,
    best = if (length(parts) < 3) {
      list(action = "error", message = "Usage: `/jinx poll best <id>`")
    } else if (!grepl(samkoma_id_pattern(), parts[3])) {
      list(action = "error", message = "Invalid poll id.")
    } else {
      list(action = "poll-best", id = parts[3])
    },
    create = parse_poll_create_command(parts[-(1:2)], usage),
    list(action = "error", message = usage)
  )
}

parse_poll_create_command <- function(tokens, usage) {
  is_kv <- grepl("^[a-zA-Z_]+=", tokens)
  first_kv <- which(is_kv)
  if (length(first_kv) == 0 || first_kv[1] == 1) {
    return(list(action = "error", message = usage))
  }
  title <- paste(tokens[seq_len(first_kv[1] - 1)], collapse = " ")

  tail_tokens <- tokens[first_kv[1]:length(tokens)]
  stray <- tail_tokens[!grepl("^[a-zA-Z_]+=", tail_tokens)]
  if (length(stray) > 0) {
    return(list(
      action = "error",
      message = glue::glue(
        "Unrecognized poll option(s): {paste(stray, collapse = ', ')}. {usage}"
      )
    ))
  }

  kv <- tokens[is_kv]
  opts <- stats::setNames(
    as.list(sub("^[^=]+=", "", kv)),
    sub("=.*$", "", kv)
  )
  poll_create_command_from_opts(title, opts, usage)
}

parse_poll_opts_days <- function(opts) {
  days <- strsplit(opts$days %||% "", ",", fixed = TRUE)[[1]]
  days[nzchar(days)]
}

poll_create_command_from_opts <- function(title, opts, usage) {
  required <- c("days", "from", "to", "slot")
  if (!all(required %in% names(opts)) || !nzchar(title)) {
    return(list(action = "error", message = usage))
  }
  days <- parse_poll_opts_days(opts)
  if (length(days) == 0) {
    return(list(
      action = "error",
      message = "`days` must list at least one day."
    ))
  }
  slot <- suppressWarnings(as.integer(opts$slot))
  if (is.na(slot) || slot <= 0L) {
    return(list(
      action = "error",
      message = "`slot` must be a positive number of minutes."
    ))
  }
  kind <- tolower(opts$kind %||% "dates")
  if (!kind %in% c("dates", "weekdays")) {
    return(list(
      action = "error",
      message = "`kind` must be `dates` or `weekdays`."
    ))
  }
  list(
    action = "poll-create",
    title = title,
    days = days,
    from = opts$from,
    to = opts$to,
    slot = slot,
    tz = opts$tz %||% "UTC",
    kind = kind,
    public = !identical(tolower(opts$public %||% "true"), "false")
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

parse_questions_command <- function(parts) {
  days <- if (length(parts) >= 2) {
    suppressWarnings(as.integer(parts[2]))
  } else {
    7L
  }
  if (is.na(days) || days <= 0) {
    return(list(
      action = "error",
      message = paste(
        "Usage: `/jinx questions [days]`",
        "where days is a positive integer"
      )
    ))
  }
  list(action = "questions", days = days)
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
#' @param command Parsed command list from [cmd_parse()].
#' @return Character string with the response message.
#' @export
cmd_execute <- function(command) {
  if (is.null(command)) {
    return(invisible(NULL))
  }

  spec <- jinx_commands()[[command$action]]
  if (is.null(spec)) {
    return(glue::glue(
      "Unknown command: `{command$action}`. Try `/jinx help` for usage."
    ))
  }
  spec$handler(command)
}

normalize_command <- function(parts) {
  phrases <- list(
    list(c("generate", "website", "analytics"), "website-analytics"),
    list(c("website", "analytics"), "website-analytics"),
    list(c("question", "log"), "questions"),
    list(c("generate", "analytics"), "analytics"),
    list(c("generate", "report"), "report"),
    list(c("generate", "dashboard"), "gha-dashboard"),
    list(c("check", "blog", "links"), "blog-check-links"),
    list(c("check", "chapter", "health"), "chapter-health"),
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
