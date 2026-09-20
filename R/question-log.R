up_reactions <- c(
  "+1",
  "thumbsup",
  "heart",
  "heart_eyes",
  "tada",
  "raised_hands",
  "star-struck",
  "100"
)
down_reactions <- c("-1", "thumbsdown", "disappointed", "confused")

#' Classify a Slack reaction as an up- or down-vote
#'
#' R port of `reaction_direction()` from `worker/src/question-log.js`.
#' Strips a skin-tone modifier suffix (e.g. `"thumbsup::skin-tone-3"`)
#' before matching.
#'
#' @param reaction Raw reaction name.
#' @return `"up"`, `"down"`, or `NULL` for a neutral reaction.
#' @export
reaction_direction <- function(reaction) {
  if (is.null(reaction) || is.na(reaction)) {
    reaction <- ""
  }
  r <- strsplit(reaction, "::", fixed = TRUE)[[1]][1]
  if (is.na(r)) {
    r <- ""
  }
  if (r %in% up_reactions) {
    return("up")
  }
  if (r %in% down_reactions) {
    return("down")
  }
  NULL
}

#' Increment the daily reaction-feedback counter for a workspace
#'
#' R port of the KV counter logic in `slack_event_handle_reaction()`
#' (`worker/src/slack-events.js`, deleted as part of the reaction-handling
#' migration). Backs `/jinx feedback`.
#'
#' @param team_id Slack team id.
#' @param reaction Raw reaction name.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return Invisibly, the new count for today.
#' @export
reaction_log_increment <- function(
  team_id,
  reaction,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  day <- format(Sys.Date(), "%Y-%m-%d")
  key <- glue::glue("reaction_log:{team_id}:{day}:{reaction}")
  prior <- tryCatch(
    jsonlite::fromJSON(cf_ops_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key,
      token = api_token
    )),
    error = function(e) NULL
  )
  count <- as.integer((prior$count %||% 0L) + 1L)
  cf_ops_kv_put(
    account_id = account_id,
    namespace_id = namespace_id,
    key_name = key,
    value = jsonlite::toJSON(
      list(
        count = count,
        last_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      auto_unbox = TRUE
    ),
    ttl_seconds = 180L * 24L * 60L * 60L,
    token = api_token
  )
  invisible(count)
}

question_vote_item_valid <- function(item) {
  !is.null(item) &&
    identical(item$type, "message") &&
    !is.null(item$channel) &&
    !is.null(item$ts)
}

question_vote_answer_id <- function(
  team_id,
  item,
  namespace_id,
  account_id,
  api_token
) {
  key <- glue::glue("answer_link:{team_id}:{item$channel}:{item$ts}")
  id_raw <- tryCatch(
    cf_ops_get_kv_value(
      account_id = account_id,
      namespace_id = namespace_id,
      key_name = key,
      token = api_token
    ),
    error = function(e) NA_character_
  )
  if (is.character(id_raw) && grepl("^[0-9]+$", id_raw %||% "")) {
    as.integer(id_raw)
  } else {
    NA_integer_
  }
}

question_vote_update_db <- function(
  id,
  column,
  account_id,
  database_id,
  api_token
) {
  tryCatch(
    {
      cloudflarer::cf_d1_query(
        account_id = account_id,
        database_id = database_id,
        sql = glue::glue(
          "UPDATE questions SET {column} = {column} + 1 WHERE id = ?"
        ),
        params = list(id),
        token = api_token
      )
      TRUE
    },
    error = function(e) {
      cli::cli_warn("question_log vote failed: {conditionMessage(e)}")
      FALSE
    }
  )
}

#' Apply a reaction vote to the question it answered
#'
#' R port of `question_vote_apply()` from `worker/src/slack-events.js`
#' (deleted as part of the reaction-handling migration). Looks up the D1
#' row an answer message links to via the `answer_link:{team_id}:
#' {channel}:{ts}` KV key, and increments its up/down count.
#'
#' @param team_id Slack team id.
#' @param item Reaction event's `item` list: `type`, `channel`, `ts`.
#' @param reaction Raw reaction name.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param database_id D1 database ID. Defaults to the provisioned
#'   `jinx-question-log` database.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return `TRUE` if a vote was applied, `FALSE` otherwise.
#' @export
question_vote_apply <- function(
  team_id,
  item,
  reaction,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  if (!question_vote_item_valid(item)) {
    return(FALSE)
  }
  dir <- reaction_direction(reaction)
  if (is.null(dir)) {
    return(FALSE)
  }

  id <- question_vote_answer_id(
    team_id,
    item,
    namespace_id,
    account_id,
    api_token
  )
  if (is.na(id)) {
    return(FALSE)
  }

  column <- if (dir == "up") "up" else "down"
  question_vote_update_db(id, column, account_id, database_id, api_token)
}

#' Apply an incoming Slack reaction event
#'
#' The `reaction_added` event handler registered in `jinx_events()`:
#' increments the reaction-feedback tally and applies a vote to the
#' question the reacted-to message answered, if any.
#'
#' @param team_id Slack team id.
#' @param event The event's `event` payload: `reaction`, `item`.
#' @return Invisibly, `NULL`.
#' @export
reaction_event_apply <- function(team_id, event) {
  reaction <- event$reaction %||% ""
  tryCatch(
    reaction_log_increment(team_id, reaction),
    error = function(e) {
      cli::cli_warn("reaction_log write failed: {conditionMessage(e)}")
    }
  )
  tryCatch(
    question_vote_apply(team_id, event$item, reaction),
    error = function(e) {
      cli::cli_warn("question_vote failed: {conditionMessage(e)}")
    }
  )
  invisible(NULL)
}

#' Query the anonymous question log
#'
#' Reads rows from the Cloudflare D1 `jinx-question-log` database via
#' [cloudflarer::cf_d1_query()] - the same table
#' `worker/src/question-log.js` writes to from inside the Cloudflare
#' Worker when `@Jinx` answers a question. No Slack user id, channel,
#' or thread timestamp is stored, so a row cannot be traced to who asked.
#'
#' @param since_day Character `YYYY-MM-DD`. Only rows on or after this
#'   day are returned. Defaults to 7 days ago.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param database_id D1 database ID. Defaults to the provisioned
#'   `jinx-question-log` database.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return Data frame with columns `id`, `day`, `question`, `outcome`,
#'   `top_score`, `sources`, `up`, `down`.
#' @export
question_log_query <- function(
  since_day = as.character(Sys.Date() - 7),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  cloudflarer::cf_d1_query(
    account_id = account_id,
    database_id = database_id,
    sql = paste(
      "SELECT id, day, question, outcome, top_score, sources, up, down",
      "FROM questions WHERE day >= ? ORDER BY day DESC"
    ),
    params = list(since_day),
    token = api_token
  )
}

#' Purge question-log rows past the retention window
#'
#' Deletes rows from the Cloudflare D1 `jinx-question-log` database older
#' than `retention_days`, honouring the 180-day retention promise in
#' PRIVACY.md. Formerly `question_log_purge()` in
#' `worker/src/question-log.js`, ported here so the retention guarantee
#' has a single implementation.
#'
#' @param retention_days Number of days to retain rows for. Defaults to 180.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param database_id D1 database ID. Defaults to the provisioned
#'   `jinx-question-log` database.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return Integer number of rows deleted.
#' @export
question_log_purge <- function(
  retention_days = 180,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  cutoff <- as.character(as.Date(Sys.time(), tz = "UTC") - retention_days)
  res <- cloudflarer::cf_d1_query(
    account_id = account_id,
    database_id = database_id,
    sql = "DELETE FROM questions WHERE day < ?",
    params = list(cutoff),
    as_df = FALSE,
    token = api_token
  )
  changes <- as.integer(res[[1]]$meta$changes %||% 0L)
  if (changes > 0L) {
    cli::cli_alert_success(
      "Purged {changes} question-log row{?s} older than {retention_days} days"
    )
  } else {
    cli::cli_alert_info(
      "No question-log rows older than {retention_days} days to purge"
    )
  }
  changes
}

question_gap_outcomes <- c("no_match", "coding_declined", "low_confidence")

normalize_question <- function(question) {
  question[is.na(question)] <- ""
  question <- tolower(question)
  question <- gsub("\\s+", " ", question)
  trimws(question)
}

#' Rank content-gap questions by normalized-duplicate count
#'
#' R port of `question_gaps_rank()` in `worker/src/question-log.js`.
#' Near-identical questions (case/whitespace-insensitive) are folded
#' together so a popular unanswered question rises to the top.
#'
#' @param rows Data frame from [question_log_query()].
#' @param limit Maximum number of gaps to return.
#' @return Data frame with columns `question`, `outcome`, `count`,
#'   ordered by `count` descending.
#' @export
question_gaps_rank <- function(rows, limit = 10) {
  empty <- data.frame(
    question = character(),
    outcome = character(),
    count = integer(),
    stringsAsFactors = FALSE
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    return(empty)
  }
  gap_rows <- rows[rows$outcome %in% question_gap_outcomes, , drop = FALSE]
  if (nrow(gap_rows) == 0L) {
    return(empty)
  }
  key <- normalize_question(gap_rows$question)
  gap_rows <- gap_rows[nzchar(key), , drop = FALSE]
  key <- key[nzchar(key)]
  if (nrow(gap_rows) == 0L) {
    return(empty)
  }
  groups <- split(seq_len(nrow(gap_rows)), key)
  out <- data.frame(
    question = vapply(
      groups,
      function(idx) gap_rows$question[idx[1]],
      character(1)
    ),
    outcome = vapply(
      groups,
      function(idx) gap_rows$outcome[idx[1]],
      character(1)
    ),
    count = vapply(groups, length, integer(1)),
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$count), , drop = FALSE]
  rownames(out) <- NULL
  utils::head(out, limit)
}

#' Rank questions where downvotes exceed upvotes
#'
#' R port of `question_downvoted_rank()` in `worker/src/question-log.js`.
#'
#' @param rows Data frame from [question_log_query()].
#' @param limit Maximum number of rows to return.
#' @return Subset of `rows` where `down > up`, ordered by `down - up`
#'   descending.
#' @export
question_downvoted_rank <- function(rows, limit = 10) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(rows)
  }
  up <- ifelse(is.na(rows$up), 0L, rows$up)
  down <- ifelse(is.na(rows$down), 0L, rows$down)
  keep <- down > up
  out <- rows[keep, , drop = FALSE]
  if (nrow(out) == 0L) {
    return(out)
  }
  out <- out[order(-(down[keep] - up[keep])), , drop = FALSE]
  rownames(out) <- NULL
  utils::head(out, limit)
}

#' Format a question-log report as markdown
#'
#' @param rows Data frame from [question_log_query()].
#' @param gaps Data frame from [question_gaps_rank()].
#' @param downvoted Data frame from [question_downvoted_rank()].
#' @param days Number of days the report covers, for the header.
#' @return Character string with markdown-formatted report.
#' @export
question_log_format <- function(rows, gaps, downvoted, days) {
  total <- if (is.null(rows)) 0L else nrow(rows)
  if (total == 0L) {
    return(glue::glue(
      "## Question Log ({days} days)\n\nNo questions logged in this period.\n"
    ))
  }

  outcome_counts <- table(rows$outcome)
  overview <- paste(
    "| Outcome | Count |",
    "|---------|-------|",
    paste(
      glue::glue_data(
        data.frame(
          outcome = names(outcome_counts),
          count = as.integer(outcome_counts)
        ),
        "| {outcome} | {count} |"
      ),
      collapse = "\n"
    ),
    sep = "\n"
  )

  gaps_section <- if (nrow(gaps) == 0L) {
    "No content gaps in this period."
  } else {
    paste(
      "| Question | Outcome | Count |",
      "|----------|---------|-------|",
      paste(
        glue::glue_data(gaps, "| {question} | {outcome} | {count} |"),
        collapse = "\n"
      ),
      sep = "\n"
    )
  }

  downvoted_section <- if (nrow(downvoted) == 0L) {
    "No downvoted answers in this period."
  } else {
    paste(
      "| Question | Up | Down |",
      "|----------|----|------|",
      paste(
        glue::glue_data(downvoted, "| {question} | {up} | {down} |"),
        collapse = "\n"
      ),
      sep = "\n"
    )
  }

  glue::glue(
    "## Question Log ({days} days)\n",
    "**Total questions**: {total}\n\n",
    "### Outcomes\n",
    "{overview}\n\n",
    "### Top content gaps\n",
    "{gaps_section}\n\n",
    "### Most downvoted answers\n",
    "{downvoted_section}\n"
  )
}

reaction_log_key_parts <- function(key_name, prefix) {
  rest <- sub(prefix, "", key_name, fixed = TRUE)
  parts <- strsplit(rest, ":", fixed = TRUE)[[1]]
  list(
    day = parts[1] %||% NA_character_,
    reaction = paste(parts[-1], collapse = ":")
  )
}

#' Summarize reaction-feedback tallies for a Slack workspace
#'
#' Aggregates the `reaction_log:{team_id}:{day}:{reaction}` KV counters
#' [reaction_log_increment()] writes, across the last `days` days.
#' Backs the `"feedback"` command. R port of `slash_feedback()` from
#' the deleted `worker/src/slash-local.js`.
#'
#' @param team_id Slack team id. Required (aborts if missing) - a blank
#'   prefix would otherwise scan every key in the namespace across both
#'   workspaces instead of just this one's.
#' @param days Number of days to look back.
#' @param namespace_id KV namespace ID for `SLACK_TOKENS`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @return A list with `days`, `entries` (integer count of KV entries
#'   scanned), and `totals` (a named integer vector, reaction name to
#'   summed count, sorted descending).
#' @export
question_feedback_summary <- function(
  team_id,
  days = 7,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
) {
  if (is.null(team_id) || length(team_id) != 1 || !nzchar(team_id)) {
    cli::cli_abort("question_feedback_summary() requires a non-empty team_id.")
  }
  since <- as.character(Sys.Date() - days)
  prefix <- glue::glue("reaction_log:{team_id}:")
  keys <- cf_ops_list_kv_keys(
    account_id = account_id,
    namespace_id = namespace_id,
    prefix = prefix,
    token = api_token
  )
  if (nrow(keys) == 0L) {
    return(list(days = days, entries = 0L, totals = integer(0)))
  }

  parsed <- lapply(keys$name, reaction_log_key_parts, prefix = prefix)
  day <- vapply(parsed, `[[`, character(1), "day")
  reaction <- vapply(parsed, `[[`, character(1), "reaction")
  keep <- !is.na(day) & nzchar(reaction) & day >= since
  if (!any(keep)) {
    return(list(days = days, entries = 0L, totals = integer(0)))
  }

  counts <- vapply(
    keys$name[keep],
    function(key_name) {
      raw <- tryCatch(
        cf_ops_get_kv_value(
          account_id = account_id,
          namespace_id = namespace_id,
          key_name = key_name,
          token = api_token
        ),
        error = function(e) NULL
      )
      entry <- tryCatch(jsonlite::fromJSON(raw), error = function(e) NULL)
      as.integer(entry$count %||% 0L)
    },
    integer(1)
  )

  totals <- sort(tapply(counts, reaction[keep], sum), decreasing = TRUE)
  list(days = days, entries = sum(keep), totals = totals)
}

#' Format a reaction-feedback summary as a reply
#'
#' @param summary A list from [question_feedback_summary()].
#' @return Character scalar reply text.
#' @export
question_feedback_format <- function(summary) {
  day_word <- if (summary$days == 1) "day" else "days"
  if (length(summary$totals) == 0L) {
    return(glue::glue(
      "\U0001F4CA No reactions on my answers in the last ",
      "{summary$days} {day_word} \u2014 either I'm doing great or no one's ",
      "looking. \U0001F408 Once folks react with \U0001F44D / \U0001F44E, ",
      "the counts will land here."
    ))
  }

  entry_word <- if (summary$entries == 1) "entry" else "entries"
  lines <- c(
    glue::glue(
      "\U0001F4CA *Jinx feedback \u2014 last {summary$days} {day_word}* ",
      "({summary$entries} {entry_word}):"
    ),
    glue::glue(":{names(summary$totals)}:  {summary$totals}")
  )
  paste(lines, collapse = "\n")
}
