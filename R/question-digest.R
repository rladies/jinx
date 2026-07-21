digest_gap_outcomes <- c("no_match", "low_confidence")

draft_system_prompt <- paste0(
  "You are helping the RLadies+ global team improve their organiser Guide. ",
  "You are given a question that Jinx (the RLadies+ assistant) could not answer well.\n\n",
  "Draft a SHORT proposed Guide answer (2\u20134 sentences) for a human to review before publishing. Rules:\n",
  "- Only state what you are genuinely confident is accurate RLadies+ practice. ",
  "If you are unsure of specifics (dates, amounts, exact process), say plainly what the team needs to confirm rather than inventing it.\n",
  "- Write the organisation name as *RLadies+* \u2014 one word, trailing plus, no hyphen.\n",
  "- No preamble, no \"here is a draft\" \u2014 just the proposed answer text.\n",
  "- Never invent URLs, names, figures, or policies."
)

digest_truncate <- function(text, max_chars = 140) {
  s <- if (is.null(text) || is.na(text)) "" else text
  s <- trimws(gsub("\\s+", " ", s))
  s <- if (nchar(s) > max_chars) {
    paste0(substr(s, 1, max_chars - 1), "\u2026")
  } else {
    s
  }
  escape_markdown(s)
}

#' Rank content gaps for the weekly digest
#'
#' Narrower sibling of [question_gaps_rank()]: excludes `"coding_declined"`
#' rows, since declining a coding question is working as designed, not a
#' corpus gap. R port of `content_gaps()` from the deleted
#' `worker/src/question-digest.js`.
#'
#' @param rows Data frame from [question_log_query()].
#' @param min_count Minimum occurrence count to keep a gap.
#' @param limit Maximum number of gaps to return.
#' @return Data frame with columns `question`, `outcome`, `count`.
#' @export
question_content_gaps <- function(rows, min_count = 1, limit = 10) {
  gap_rows <- if (is.null(rows) || nrow(rows) == 0L) {
    rows
  } else {
    rows[rows$outcome %in% digest_gap_outcomes, , drop = FALSE]
  }
  gaps <- question_gaps_rank(gap_rows, limit)
  gaps[gaps$count >= min_count, , drop = FALSE]
}

#' Count coding questions Jinx declined
#'
#' @param rows Data frame from [question_log_query()].
#' @return Integer count of `outcome == "coding_declined"` rows.
#' @export
question_coding_declined_count <- function(rows) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(0L)
  }
  as.integer(sum(rows$outcome == "coding_declined", na.rm = TRUE))
}

#' Draft a proposed Guide answer for a content-gap question
#'
#' Calls Workers AI to draft a short, human-reviewable answer for a question
#' Jinx could not answer well. Failures are swallowed - a digest with an
#' undrafted gap is better than a failed scheduled run. R port of
#' `draft_guide_snippet()` from the deleted `worker/src/question-digest.js`.
#'
#' @param question The question Jinx could not answer well.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return Character scalar draft, or `NULL` if the model call failed or
#'   returned nothing usable.
#' @export
question_draft_guide_snippet <- function(
  question,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  draft <- tryCatch(
    cloudflare_generate(
      messages = list(
        list(role = "system", content = draft_system_prompt),
        list(
          role = "user",
          content = glue::glue(
            "Question Jinx could not answer well:\n\"{question}\"\n\nDraft a proposed Guide answer."
          )
        )
      ),
      account_id = account_id,
      api_token = api_token,
      model = model,
      max_tokens = 250
    ),
    error = function(e) {
      cli::cli_warn("draft_guide_snippet failed: {conditionMessage(e)}")
      NULL
    }
  )
  draft <- trimws(draft %||% "")
  if (nzchar(draft)) draft else NULL
}

#' Format the weekly question-gap digest as Slack mrkdwn
#'
#' Distinct from [question_log_format()], which renders a GitHub-comment
#' markdown report for `/jinx questions` - this builds the Slack message
#' text posted by [question_digest_post()]. R port of `format_digest()`
#' from the deleted `worker/src/question-digest.js`.
#'
#' @param days Number of days the report covers.
#' @param total Total questions logged in the period.
#' @param gaps Data frame from [question_content_gaps()].
#' @param drafts Data frame: the top-drafted subset of `gaps`, plus a
#'   `draft` character column (`NA` where drafting failed).
#' @param downvoted Data frame from [question_downvoted_rank()].
#' @param coding_count Integer from [question_coding_declined_count()].
#' @return Character scalar Slack mrkdwn message.
#' @export
question_digest_format <- function(
  days,
  total,
  gaps,
  drafts,
  downvoted,
  coding_count
) {
  day_word <- if (days == 1) "day" else "days"
  question_word <- if (total == 1) "question" else "questions"
  lines <- glue::glue(
    "\U0001F52E *Jinx weekly question review \u2014 last {days} {day_word}* ",
    "({total} {question_word} logged)"
  )

  n_drafts <- nrow(drafts)
  if (n_drafts > 0L) {
    lines <- c(
      lines,
      "",
      "*Gaps to close* \u2014 the Guide may be thin here. Each carries a *draft* answer to review:"
    )
    for (i in seq_len(n_drafts)) {
      d_question <- drafts$question[i]
      d_count <- drafts$count[i]
      d_draft <- drafts$draft[i]
      times <- if (d_count > 1) {
        glue::glue(" _(asked \u00D7{d_count})_")
      } else {
        ""
      }
      lines <- c(
        lines,
        "",
        glue::glue("\u2022 *{digest_truncate(d_question)}*{times}")
      )
      lines <- c(
        lines,
        if (!is.na(d_draft) && nzchar(d_draft)) {
          glue::glue("    \u25E6 _draft:_ {escape_markdown(d_draft)}")
        } else {
          "    \u25E6 _(couldn't draft one \u2014 needs the team to write this)_"
        }
      )
    }
  }

  undrafted <- if (nrow(gaps) > n_drafts) {
    gaps[seq(n_drafts + 1L, nrow(gaps)), , drop = FALSE]
  } else {
    gaps[0L, , drop = FALSE]
  }
  if (nrow(undrafted) > 0L) {
    lines <- c(lines, "", "*More gaps* (no draft \u2014 pick these up next):")
    for (i in seq_len(nrow(undrafted))) {
      g_question <- undrafted$question[i]
      g_count <- undrafted$count[i]
      times <- if (g_count > 1) glue::glue(" _(\u00D7{g_count})_") else ""
      lines <- c(
        lines,
        glue::glue("\u2022 {digest_truncate(g_question)}{times}")
      )
    }
  }

  if (nrow(gaps) == 0L) {
    lines <- c(
      lines,
      "",
      "*Gaps to close:* none this week \u2014 I answered everything asked. \U0001F63A"
    )
  }

  if (nrow(downvoted) > 0L) {
    lines <- c(
      lines,
      "",
      "*Answers folks \U0001F44E'd* (may be wrong, stale, or mis-retrieved):"
    )
    for (i in seq_len(nrow(downvoted))) {
      lines <- c(
        lines,
        glue::glue(
          "\u2022 {digest_truncate(downvoted$question[i])} \u2014 ",
          "\U0001F44E {downvoted$down[i]} / \U0001F44D {downvoted$up[i]}"
        )
      )
    }
  }

  if (coding_count > 0L) {
    coding_word <- if (coding_count == 1) "question" else "questions"
    lines <- c(
      lines,
      "",
      glue::glue(
        "_FYI: I declined {coding_count} coding {coding_word} \u2192 pointed to *#help-r* ",
        "(working as designed, not a Guide gap)._"
      )
    )
  }

  lines <- c(
    lines,
    "",
    paste0(
      "\U0001F408\u200D\U00002B1B _Drafts are AI-suggested and *unverified* \u2014 ",
      "please confirm before adding anything to the Guide._"
    )
  )

  paste(lines, collapse = "\n")
}

#' Build the weekly question-gap digest text
#'
#' Queries the anonymous question log, ranks content gaps and downvoted
#' answers, drafts a proposed Guide answer for the top gaps, and formats
#' the lot as Slack mrkdwn. R port of `question_digest_build()` from the
#' deleted `worker/src/question-digest.js`.
#'
#' @param days Number of days to cover. Defaults to 7.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param database_id D1 database ID. Defaults to the provisioned
#'   `jinx-question-log` database.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model used for drafting.
#' @return Character scalar digest text, or `NULL` when nothing was logged.
#' @export
question_digest_build <- function(
  days = 7,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  rows <- question_log_query(
    since_day = as.character(Sys.Date() - days),
    account_id = account_id,
    database_id = database_id,
    api_token = api_token
  )
  if (is.null(rows) || nrow(rows) == 0L) {
    return(NULL)
  }

  gaps <- question_content_gaps(rows, min_count = 1, limit = 10)
  downvoted <- question_downvoted_rank(rows, limit = 5)
  coding_count <- question_coding_declined_count(rows)

  n_draft <- min(5L, nrow(gaps))
  drafts <- gaps[seq_len(n_draft), , drop = FALSE]
  drafts$draft <- vapply(
    drafts$question,
    function(q) {
      question_draft_guide_snippet(q, account_id, api_token, model) %||%
        NA_character_
    },
    character(1)
  )

  question_digest_format(
    days = days,
    total = nrow(rows),
    gaps = gaps,
    drafts = drafts,
    downvoted = downvoted,
    coding_count = coding_count
  )
}

#' Build and post the weekly question-gap digest to Slack
#'
#' @param days Number of days to cover. Defaults to 7.
#' @param channel Slack channel to post to. Defaults to env
#'   `SLACK_DIGEST_CHANNEL`, falling back to `"team-jinx"`.
#' @param slack_token Slack bot token. Defaults to env `SLACK_TOKEN`.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param database_id D1 database ID. Defaults to the provisioned
#'   `jinx-question-log` database.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model used for drafting.
#' @return Invisibly, `TRUE` if a digest was posted, `FALSE` if there was
#'   nothing to report.
#' @export
question_digest_post <- function(
  days = 7,
  channel = Sys.getenv("SLACK_DIGEST_CHANNEL", "team-jinx"),
  slack_token = Sys.getenv("SLACK_TOKEN"),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  text <- question_digest_build(days, account_id, database_id, api_token, model)
  if (is.null(text)) {
    cli::cli_alert_info("No digest to post for the last {days} days")
    return(invisible(FALSE))
  }
  resp <- slack_post_message(text, channel = channel, token = slack_token)
  if (!isTRUE(resp$ok)) {
    cli::cli_abort(
      "Failed to post weekly digest to #{channel}: {resp$error %||% 'unknown error'}"
    )
  }
  invisible(TRUE)
}
