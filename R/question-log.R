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
