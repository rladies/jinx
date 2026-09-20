#' Difficulty levels for the weekly R challenge
#'
#' @return Data frame with columns `level`, `label`, and `badge` (a Slack
#'   emoji), one row per difficulty.
#' @export
r_challenge_difficulties <- function() {
  data.frame(
    level = c("beginner", "intermediate", "advanced"),
    label = c("Novice", "Adept", "Oracle"),
    badge = c("\U0001F7E2", "\U0001F7E1", "\U0001F534"),
    stringsAsFactors = FALSE
  )
}

challenge_difficulty_row <- function(difficulty) {
  levels <- r_challenge_difficulties()
  row <- levels[levels$level == tolower(difficulty), , drop = FALSE]
  if (nrow(row) == 0L) {
    cli::cli_abort("Unknown challenge difficulty {.val {difficulty}}.")
  }
  row
}

#' Slack emoji badge for a difficulty level
#'
#' @param difficulty One of the levels in [r_challenge_difficulties()].
#' @return Character scalar emoji.
#' @export
r_challenge_difficulty_badge <- function(difficulty) {
  challenge_difficulty_row(difficulty)$badge
}

#' Human-readable label for a difficulty level
#'
#' @param difficulty One of the levels in [r_challenge_difficulties()].
#' @return Character scalar label.
#' @export
r_challenge_difficulty_label <- function(difficulty) {
  challenge_difficulty_row(difficulty)$label
}

#' Packages a generated challenge may rely on
#'
#' Constrains what the generator may use and what the container running the
#' reprex verification must provide: base R plus a small tidyverse core.
#'
#' @return Character vector of package names.
#' @export
r_challenge_allowed_packages <- function() {
  c(
    "base",
    "stats",
    "utils",
    "dplyr",
    "tidyr",
    "purrr",
    "stringr",
    "forcats",
    "tibble",
    "readr",
    "ggplot2",
    "lubridate"
  )
}

challenge_gen_system_prompt <- function() {
  paste0(
    "You are Jinx, setting a weekly R coding challenge for the RLadies+ ",
    "community, a global community of R users at every level. Produce ONE ",
    "self-contained R challenge.\n\n",
    "Return ONLY a single JSON object, with no prose and no code fences, ",
    "with these keys:\n",
    "- title: a short catchy name (max ~6 words).\n",
    "- difficulty: exactly one of \"beginner\", \"intermediate\", ",
    "\"advanced\".\n",
    "- statement: R code that STATES the challenge and is run as-is to show ",
    "solvers what to do. It must contain, as runnable R: a comment naming the ",
    "function to write and its arguments, any input setup, and the expected ",
    "result shown as a LITERAL value (so it prints). Do NOT call the function ",
    "being asked for (it does not exist yet) and do NOT include the ",
    "solution.\n",
    "- solution: a correct, self-contained reference solution in R (kept ",
    "hidden from solvers). Define every function the tests call, and call ",
    "library() for any non-base package.\n",
    "- tests: an array of R expressions (as strings) that each evaluate to ",
    "TRUE when the solution is correct, e.g. \"identical(double(2), 4)\". ",
    "Provide at least two, covering a normal case and an edge case. The ",
    "expected result shown in statement MUST match what the solution ",
    "produces.\n\n",
    "Hard rules:\n",
    "- Use only base R or these packages: ",
    paste(r_challenge_allowed_packages(), collapse = ", "),
    ".\n",
    "- statement, solution and tests MUST be deterministic: no Sys.time(), ",
    "no unseeded sample() or runif(); if randomness is needed, call ",
    "set.seed().\n",
    "- No file, network, or system access.\n",
    "- Calibrate the difficulty honestly for a community learner.\n\n",
    "Example statement value: ",
    "\"# Write square_evens(x): the squares of the even numbers in x.\\n",
    "x <- c(1, 2, 3, 4, 5, 6)\\n",
    "# square_evens(x) should return:\\nc(4, 16, 36)\""
  )
}

challenge_critic_system_prompt <- function() {
  paste0(
    "You are an adversarial reviewer of a weekly R coding challenge for the ",
    "RLadies+ community. Your job is to find reasons the challenge should NOT ",
    "be published. Reject it if ANY of these hold:\n",
    "- The task is ambiguous or under-specified.\n",
    "- It is not solvable as written, the reference solution does not match ",
    "the statement, or the expected result shown in the statement does not ",
    "match what the solution produces.\n",
    "- The stated difficulty is clearly wrong.\n",
    "- It relies on packages outside base R or the allowed set, on file, ",
    "network, or system access, or is non-deterministic.\n",
    "- It is offensive, off-topic, or not genuinely about R.\n\n",
    "You are given the challenge and the captured output of running its ",
    "reference solution against its own tests. Return ONLY a JSON object: ",
    "{\"verdict\": \"approve\" | \"reject\", \"issues\": [\"...\"]}. Answer ",
    "\"approve\" only if you are confident the challenge is correct, ",
    "unambiguous, and fairly rated. When in doubt, reject."
  )
}

#' Ask Workers AI to draft a weekly R challenge
#'
#' Low-level generator: returns the model's raw completion, which
#' [r_challenge_parse()] turns into a structured challenge. Most callers want
#' [r_challenge_draft_build()], which also verifies the result.
#'
#' @param difficulty Optional difficulty to request; `NULL` lets the model
#'   choose.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return Character scalar with the model's raw response.
#' @export
r_challenge_generate <- function(
  difficulty = NULL,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  user <- if (is.null(difficulty)) {
    "Set this week's challenge."
  } else {
    glue::glue("Set this week's challenge at {tolower(difficulty)} difficulty.")
  }
  cloudflare_generate(
    messages = list(
      list(role = "system", content = challenge_gen_system_prompt()),
      list(role = "user", content = as.character(user))
    ),
    account_id = account_id,
    api_token = api_token,
    model = model,
    max_tokens = 700
  )
}

is_scalar_string <- function(x) {
  length(x) == 1L && is.character(x) && !is.na(x) && nzchar(trimws(x))
}

challenge_extract_json <- function(text) {
  if (!is_scalar_string(text)) {
    return(NA_character_)
  }
  start <- regexpr("\\{", text)
  closes <- gregexpr("\\}", text)[[1]]
  if (start < 1L || closes[1] < 0L) {
    return(NA_character_)
  }
  substr(text, start, max(closes))
}

challenge_scalar_field <- function(value) {
  if (!is_scalar_string(value)) {
    return(NULL)
  }
  trimws(value)
}

challenge_clean_tests <- function(tests) {
  if (is.list(tests)) {
    tests <- unlist(tests)
  }
  if (!is.character(tests)) {
    return(character())
  }
  tests[!is.na(tests) & nzchar(trimws(tests))]
}

challenge_validate <- function(parsed) {
  scalars <- c("title", "difficulty", "statement", "solution")
  if (!all(c(scalars, "tests") %in% names(parsed))) {
    return(NULL)
  }
  fields <- lapply(scalars, function(field) {
    challenge_scalar_field(parsed[[field]])
  })
  names(fields) <- scalars
  if (any(vapply(fields, is.null, logical(1)))) {
    return(NULL)
  }
  difficulty <- tolower(fields$difficulty)
  if (!difficulty %in% r_challenge_difficulties()$level) {
    return(NULL)
  }
  tests <- challenge_clean_tests(parsed$tests)
  if (length(tests) == 0L) {
    return(NULL)
  }
  list(
    title = fields$title,
    difficulty = difficulty,
    statement = fields$statement,
    solution = fields$solution,
    tests = tests
  )
}

challenge_parse_json <- function(text) {
  json <- challenge_extract_json(text)
  if (is.na(json)) {
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(json), error = function(e) NULL)
}

#' Parse a model completion into a structured challenge
#'
#' Tolerates prose or code fences around the JSON. Returns `NULL` for any
#' output missing a required field, carrying an unknown difficulty, or without
#' at least one machine-checkable test, so callers can regenerate.
#'
#' @param text Raw model completion from [r_challenge_generate()].
#' @return A list with elements `title`, `difficulty`, `statement`, `solution`,
#'   and `tests` (character vector), or `NULL` if invalid.
#' @export
r_challenge_parse <- function(text) {
  parsed <- challenge_parse_json(text)
  if (is.null(parsed) || !is.list(parsed)) {
    return(NULL)
  }
  challenge_validate(parsed)
}

r_challenge_env_keep <- function(names) {
  allowed <- c(
    "PATH",
    "HOME",
    "LANG",
    "LANGUAGE",
    "TZ",
    "TMPDIR",
    "TMP",
    "TEMP",
    "R_HOME"
  )
  names %in% allowed | grepl("^(R_LIBS|LC_)", names)
}

#' Run challenge code in an isolated R session
#'
#' Default verification runner: executes code with [reprex::reprex()] inside a
#' fresh [callr::r()] session that has a wall-clock timeout and an allowlisted
#' environment (only locale, path and temp vars pass; user
#' `.Renviron`/`.Rprofile` are disabled), so running model- or user-generated
#' code cannot reach operator secrets or hang the caller.
#'
#' @param code Character vector of R source lines to run.
#' @param timeout Wall-clock timeout in seconds.
#' @return Character vector: the rendered reprex output.
#' @keywords internal
#' @noRd
r_challenge_reprex_runner <- function(code, timeout = 60) {
  if (
    !requireNamespace("reprex", quietly = TRUE) ||
      !requireNamespace("callr", quietly = TRUE)
  ) {
    cli::cli_abort(
      "{.pkg reprex} and {.pkg callr} are needed to verify challenges."
    )
  }
  keep <- r_challenge_env_keep
  environment(keep) <- baseenv()
  callr::r(
    function(lines, keep) {
      names_now <- names(Sys.getenv())
      Sys.unsetenv(names_now[!keep(names_now)])
      no_config <- file.path(tempdir(), ".jinx-no-user-config")
      Sys.setenv(R_ENVIRON_USER = no_config, R_PROFILE_USER = no_config)
      reprex::reprex(
        input = lines,
        render = TRUE,
        advertise = FALSE,
        html_preview = FALSE
      )
    },
    args = list(lines = code, keep = keep),
    timeout = timeout
  )
}

challenge_reprex_failed <- function(out) {
  length(out) == 0L || any(grepl("^#> Error", out))
}

#' Verify a reference solution against its own tests
#'
#' Assembles the solution plus a `base::stopifnot()` for each test, runs it
#' through `runner`, and treats an `#> Error` line (a failed test or a broken
#' solution) as verification failure.
#'
#' @param solution Character scalar reference solution.
#' @param tests Character vector of R expressions expected to be `TRUE`.
#' @param runner Function taking a character vector of code lines and
#'   returning the rendered output. Defaults to the isolated reprex runner.
#' @return List with `ok` (logical) and `output` (character vector).
#' @export
r_challenge_reprex_check <- function(
  solution,
  tests,
  runner = r_challenge_reprex_runner
) {
  if (length(tests) == 0L) {
    return(list(ok = FALSE, output = "no tests supplied"))
  }
  solution_lines <- unlist(strsplit(solution, "\n", fixed = TRUE))
  code <- c(solution_lines, "", paste0("base::stopifnot(", tests, ")"))
  out <- tryCatch(
    runner(code),
    error = function(e) {
      structure(conditionMessage(e), class = "challenge_run_error")
    }
  )
  if (inherits(out, "challenge_run_error")) {
    return(list(ok = FALSE, output = as.character(out)))
  }
  list(ok = !challenge_reprex_failed(out), output = out)
}

#' Render a challenge statement as a reprex
#'
#' Runs the statement (task comment + setup + expected output as literals)
#' through the reprex runner, producing the rendered block shown to solvers.
#' Because it runs the statement on its own, a statement that leaks the answer
#' by calling the not-yet-written function errors out and is rejected.
#'
#' @param statement Character scalar of R source stating the challenge.
#' @param runner Function taking code lines and returning rendered reprex
#'   output. Defaults to the isolated reprex runner.
#' @return List with `ok` (logical) and `rendered` (character vector).
#' @export
r_challenge_render_statement <- function(
  statement,
  runner = r_challenge_reprex_runner
) {
  lines <- unlist(strsplit(statement, "\n", fixed = TRUE))
  out <- tryCatch(
    runner(lines),
    error = function(e) {
      structure(conditionMessage(e), class = "challenge_run_error")
    }
  )
  if (inherits(out, "challenge_run_error")) {
    return(list(ok = FALSE, rendered = as.character(out)))
  }
  list(ok = !challenge_reprex_failed(out), rendered = out)
}

challenge_parse_verdict <- function(raw) {
  parsed <- challenge_parse_json(raw)
  if (is.null(parsed)) {
    return(list(
      ok = FALSE,
      verdict = "unparseable",
      issues = "no verdict returned"
    ))
  }
  verdict <- tolower(trimws(parsed$verdict %||% ""))
  issues <- parsed$issues %||% character()
  if (is.list(issues)) {
    issues <- unlist(issues)
  }
  list(
    ok = identical(verdict, "approve"),
    verdict = verdict,
    issues = as.character(issues)
  )
}

#' Adversarially review a candidate challenge
#'
#' Second, independent Workers AI pass that is prompted to reject the
#' challenge unless it is confident it is correct, unambiguous, and fairly
#' rated. Fails closed: any error or unparseable verdict counts as rejection.
#'
#' @param challenge Parsed challenge from [r_challenge_parse()].
#' @param reprex_output Captured verification output from
#'   [r_challenge_reprex_check()].
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return List with `ok` (logical), `verdict`, and `issues` (character
#'   vector).
#' @export
r_challenge_adversarial_check <- function(
  challenge,
  reprex_output = character(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  user <- paste(
    c(
      glue::glue("Difficulty: {challenge$difficulty}"),
      glue::glue("Title: {challenge$title}"),
      "Statement (shown to solvers):",
      challenge$statement,
      "Reference solution (hidden):",
      challenge$solution,
      "Tests:",
      challenge$tests,
      "",
      "Output of running the solution against the tests:",
      reprex_output
    ),
    collapse = "\n"
  )
  raw <- tryCatch(
    cloudflare_generate(
      messages = list(
        list(role = "system", content = challenge_critic_system_prompt()),
        list(role = "user", content = user)
      ),
      account_id = account_id,
      api_token = api_token,
      model = model,
      max_tokens = 400
    ),
    error = function(e) {
      cli::cli_warn("adversarial check failed to run: {conditionMessage(e)}")
      NULL
    }
  )
  challenge_parse_verdict(raw)
}

#' Draft a fully verified weekly R challenge
#'
#' Orchestrates the full generator: draft with Workers AI, parse, verify the
#' reference solution with reprex, render the statement as a reprex, then
#' adversarially review. Regenerates on any failed gate, up to `max_tries`, and
#' returns `NULL` if none passes, so a scheduled run never emits unverified
#' output.
#'
#' @param difficulty Optional difficulty to request; `NULL` lets the model
#'   choose.
#' @param max_tries Maximum generate-and-verify attempts before giving up.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return A list with `challenge`, `statement` (rendered statement reprex),
#'   `reprex` (solution verification output), `critique`, and `attempts`, or
#'   `NULL` if no verified challenge was produced.
#' @export
r_challenge_draft_build <- function(
  difficulty = NULL,
  max_tries = 3L,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
) {
  for (attempt in seq_len(max_tries)) {
    raw <- tryCatch(
      r_challenge_generate(difficulty, account_id, api_token, model),
      error = function(e) {
        cli::cli_warn("generation failed: {conditionMessage(e)}")
        NULL
      }
    )
    challenge <- r_challenge_parse(raw)
    if (is.null(challenge)) {
      cli::cli_alert_info(
        "Attempt {attempt}: model output was not a valid challenge"
      )
      next
    }
    verify <- r_challenge_reprex_check(challenge$solution, challenge$tests)
    if (!isTRUE(verify$ok)) {
      cli::cli_alert_info(
        "Attempt {attempt}: reference solution failed reprex verification"
      )
      next
    }
    statement <- r_challenge_render_statement(challenge$statement)
    if (!isTRUE(statement$ok)) {
      cli::cli_alert_info(
        "Attempt {attempt}: challenge statement did not render as a reprex"
      )
      next
    }
    critique <- r_challenge_adversarial_check(
      challenge,
      verify$output,
      account_id,
      api_token,
      model
    )
    if (!isTRUE(critique$ok)) {
      cli::cli_alert_info(
        "Attempt {attempt}: rejected by adversarial review ({critique$verdict})"
      )
      next
    }
    return(list(
      challenge = challenge,
      statement = statement$rendered,
      reprex = verify$output,
      critique = critique,
      attempts = attempt
    ))
  }
  cli::cli_warn("No verified challenge produced in {max_tries} attempt{?s}")
  NULL
}

challenge_code_fence <- function(code, lang = "r") {
  # Strip backticks so model/reprex content cannot break out of the code fence.
  clean <- gsub("`", "", code)
  paste0("```", lang, "\n", clean, "\n```")
}

challenge_statement_block <- function(rendered) {
  lines <- unlist(strsplit(
    paste(rendered, collapse = "\n"),
    "\n",
    fixed = TRUE
  ))
  lines <- lines[!grepl("^```", lines)]
  lines <- gsub("`", "", lines)
  while (length(lines) > 0L && !nzchar(trimws(lines[1]))) {
    lines <- lines[-1]
  }
  while (length(lines) > 0L && !nzchar(trimws(lines[length(lines)]))) {
    lines <- lines[-length(lines)]
  }
  paste0("```\n", paste(lines, collapse = "\n"), "\n```")
}

#' Format a challenge as a Slack message
#'
#' Renders the difficulty badge, title, and the challenge's reprex statement
#' for posting to the community channel. The title flows through
#' `escape_markdown()` and the statement sits in a fenced code block (its
#' backticks stripped), so model- or user-generated text cannot inject links or
#' `<!channel>` mass-pings. The reference solution is never shown.
#'
#' @param title Challenge title.
#' @param difficulty Difficulty level (see [r_challenge_difficulties()]).
#' @param statement Rendered reprex statement (character vector or scalar).
#' @return Character scalar Slack mrkdwn message.
#' @export
r_challenge_format_slack <- function(title, difficulty, statement) {
  badge <- r_challenge_difficulty_badge(difficulty)
  label <- r_challenge_difficulty_label(difficulty)
  lines <- c(
    glue::glue("\U0001F52E *What's brewing in the cauldron?*"),
    glue::glue("This week's R challenge \u2014 {badge} *{label}*"),
    "",
    glue::glue("*{escape_markdown(title)}*"),
    "",
    challenge_statement_block(statement),
    "",
    glue::glue(
      "React \u2705 if you cracked it, \U0001F914 if you're still stewing ",
      "\u2014 share your brew in the \U0001F9F5"
    )
  )
  paste(lines, collapse = "\n")
}

#' GitHub issue title for a drafted challenge
#'
#' @param challenge Parsed challenge from [r_challenge_parse()].
#' @return Character scalar issue title.
#' @export
r_challenge_issue_title <- function(challenge) {
  as.character(glue::glue(
    "Challenge: {challenge$title} [{challenge$difficulty}]"
  ))
}

#' Format a drafted challenge as a GitHub review issue
#'
#' Builds the Markdown body an organiser reviews before approving: the rendered
#' statement in the open, with the reference solution, reprex verification
#' output, and adversarial notes in collapsed sections.
#'
#' @param build Result of [r_challenge_draft_build()].
#' @param source Where the challenge came from, e.g. `"ai"` or `"community"`.
#' @return Character scalar Markdown issue body.
#' @export
r_challenge_format_issue <- function(build, source = "ai") {
  challenge <- build$challenge
  badge <- r_challenge_difficulty_badge(challenge$difficulty)
  label <- r_challenge_difficulty_label(challenge$difficulty)
  critique <- build$critique
  issues <- if (length(critique$issues) > 0L) {
    paste(paste0("- ", critique$issues), collapse = "\n")
  } else {
    "- (none noted)"
  }
  lines <- c(
    glue::glue("## {challenge$title}"),
    "",
    glue::glue("**Difficulty:** {badge} {label}  "),
    glue::glue("**Source:** {source}  "),
    glue::glue(
      "**Verification:** reprex-checked, adversarial verdict ",
      "`{critique$verdict}`"
    ),
    "",
    "### Challenge",
    "",
    challenge_statement_block(build$statement),
    "",
    "<details><summary>Reference solution (verified)</summary>",
    "",
    challenge_code_fence(challenge$solution),
    "",
    "</details>",
    "",
    "<details><summary>reprex verification output</summary>",
    "",
    challenge_code_fence(paste(build$reprex, collapse = "\n"), lang = ""),
    "",
    "</details>",
    "",
    "### Adversarial review",
    issues,
    "",
    "---",
    paste0(
      "_Auto-drafted by Jinx. An organiser must review this and add the ",
      "`status:approved` label before it is posted to the community._"
    )
  )
  paste(lines, collapse = "\n")
}
