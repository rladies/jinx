#' Difficulty levels for the weekly R challenge
#'
#' @return Data frame with columns `level`, `label`, and `badge` (a Slack
#'   emoji), one row per difficulty.
#' @export
r_challenge_difficulties <- function() {
  data.frame(
    level = c("beginner", "intermediate", "advanced"),
    label = c("Beginner", "Intermediate", "Advanced"),
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
    "- prompt: 2-4 sentences stating the task precisely and unambiguously, ",
    "including the required function name and its arguments.\n",
    "- sample: a short example call and its expected result, as R code.\n",
    "- solution: a correct, self-contained reference solution in R. Define ",
    "every function the tests call, and call library() for any non-base ",
    "package.\n",
    "- tests: an array of R expressions (as strings) that each evaluate to ",
    "TRUE when the solution is correct, e.g. \"identical(double(2), 4)\". ",
    "Provide at least two, covering a normal case and an edge case.\n\n",
    "Hard rules:\n",
    "- Use only base R or these packages: ",
    paste(r_challenge_allowed_packages(), collapse = ", "),
    ".\n",
    "- The solution and tests MUST be deterministic: no Sys.time(), no ",
    "unseeded sample() or runif(); if randomness is needed, call set.seed() ",
    "inside the solution.\n",
    "- No file, network, or system access.\n",
    "- Calibrate the difficulty honestly for a community learner."
  )
}

challenge_critic_system_prompt <- function() {
  paste0(
    "You are an adversarial reviewer of a weekly R coding challenge for the ",
    "RLadies+ community. Your job is to find reasons the challenge should NOT ",
    "be published. Reject it if ANY of these hold:\n",
    "- The task is ambiguous or under-specified.\n",
    "- It is not solvable as written, or the reference solution does not ",
    "match the prompt.\n",
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

challenge_extract_json <- function(text) {
  if (is.null(text) || !nzchar(trimws(text %||% ""))) {
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
  if (length(value) != 1L || !is.character(value) || !nzchar(trimws(value))) {
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
  as.character(tests[!is.na(tests) & nzchar(trimws(tests))])
}

challenge_validate <- function(parsed) {
  scalars <- c("title", "difficulty", "prompt", "sample", "solution")
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
    prompt = fields$prompt,
    sample = fields$sample,
    solution = fields$solution,
    tests = tests
  )
}

#' Parse a model completion into a structured challenge
#'
#' Tolerates prose or code fences around the JSON. Returns `NULL` for any
#' output missing a required field, carrying an unknown difficulty, or without
#' at least one machine-checkable test, so callers can regenerate.
#'
#' @param text Raw model completion from [r_challenge_generate()].
#' @return A list with elements `title`, `difficulty`, `prompt`, `sample`,
#'   `solution`, and `tests` (character vector), or `NULL` if invalid.
#' @export
r_challenge_parse <- function(text) {
  json <- challenge_extract_json(text)
  if (is.na(json)) {
    return(NULL)
  }
  parsed <- tryCatch(jsonlite::fromJSON(json), error = function(e) NULL)
  if (is.null(parsed) || !is.list(parsed)) {
    return(NULL)
  }
  challenge_validate(parsed)
}

#' Run a challenge's reference solution in an isolated R session
#'
#' Default verification runner: executes the solution and its tests with
#' [reprex::reprex()] inside a fresh [callr::r()] session that has a
#' wall-clock timeout and a secret-scrubbed environment, so running
#' model-generated code cannot reach tokens or hang the caller.
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
  env <- Sys.getenv()
  secret <- grepl(
    "TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL",
    names(env),
    ignore.case = TRUE
  )
  env <- env[!secret]
  callr::r(
    function(lines) {
      reprex::reprex(
        input = lines,
        render = TRUE,
        advertise = FALSE,
        html_preview = FALSE
      )
    },
    args = list(lines = code),
    timeout = timeout,
    env = env
  )
}

#' Verify a reference solution against its own tests
#'
#' Assembles the solution plus a `stopifnot()` for each test, runs it through
#' `runner`, and treats an `#> Error` line (a failed test or a broken
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
  code <- c(solution_lines, "", paste0("stopifnot(", tests, ")"))
  out <- tryCatch(
    runner(code),
    error = function(e) {
      structure(conditionMessage(e), class = "challenge_run_error")
    }
  )
  if (inherits(out, "challenge_run_error")) {
    return(list(ok = FALSE, output = as.character(out)))
  }
  failed <- length(out) == 0L || any(grepl("^#> Error", out))
  list(ok = !failed, output = out)
}

challenge_parse_verdict <- function(raw) {
  json <- challenge_extract_json(raw %||% "")
  if (is.na(json)) {
    return(list(
      ok = FALSE,
      verdict = "unparseable",
      issues = "no verdict returned"
    ))
  }
  parsed <- tryCatch(jsonlite::fromJSON(json), error = function(e) NULL)
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
  user <- paste0(
    "Difficulty: ",
    challenge$difficulty,
    "\n",
    "Title: ",
    challenge$title,
    "\n",
    "Prompt: ",
    challenge$prompt,
    "\n",
    "Sample: ",
    challenge$sample,
    "\n",
    "Reference solution:\n",
    challenge$solution,
    "\n",
    "Tests:\n",
    paste(challenge$tests, collapse = "\n"),
    "\n\n",
    "Output of running the solution against the tests:\n",
    paste(reprex_output, collapse = "\n")
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
#' reference solution with reprex, then adversarially review. Regenerates on
#' any failed gate, up to `max_tries`, and returns `NULL` if none passes, so a
#' scheduled run never emits unverified output.
#'
#' @param difficulty Optional difficulty to request; `NULL` lets the model
#'   choose.
#' @param max_tries Maximum generate-and-verify attempts before giving up.
#' @param account_id Cloudflare account ID. Defaults to env
#'   `CLOUDFLARE_ACCOUNT_ID`.
#' @param api_token Cloudflare API token. Defaults to env
#'   `CLOUDFLARE_API_TOKEN`.
#' @param model Workers AI chat model.
#' @return A list with `challenge`, `reprex` (verification output),
#'   `critique`, and `attempts`, or `NULL` if no verified challenge was
#'   produced.
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
      reprex = verify$output,
      critique = critique,
      attempts = attempt
    ))
  }
  cli::cli_warn("No verified challenge produced in {max_tries} attempt{?s}")
  NULL
}

challenge_code_fence <- function(code, lang = "r") {
  clean <- gsub("`", "", code)
  paste0("```", lang, "\n", clean, "\n```")
}

#' Format a challenge as a Slack message
#'
#' Renders the difficulty badge, title, prompt, and a sample call for posting
#' to the community channel. Prose flows through `escape_markdown()` and the
#' sample sits in a fenced code block, so model-generated text cannot inject
#' links or `<!channel>` mass-pings. The reference solution is never shown.
#'
#' @param challenge Parsed challenge from [r_challenge_parse()].
#' @return Character scalar Slack mrkdwn message.
#' @export
r_challenge_format_slack <- function(challenge) {
  badge <- r_challenge_difficulty_badge(challenge$difficulty)
  label <- r_challenge_difficulty_label(challenge$difficulty)
  lines <- c(
    glue::glue("\U0001F9E9 *Weekly R Challenge* \u2014 {badge} {label}"),
    "",
    glue::glue("*{escape_markdown(challenge$title)}*"),
    "",
    escape_markdown(challenge$prompt),
    "",
    "_Example:_",
    challenge_code_fence(challenge$sample),
    "",
    glue::glue(
      "React \u2705 if you solved it, \U0001F914 if you're stuck \u2014 ",
      "and share your solution in the \U0001F9F5"
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
#' Builds the Markdown body an organiser reviews before approving: the prompt
#' and sample in the open, with the reference solution, reprex verification
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
    challenge$prompt,
    "",
    "### Example",
    challenge_code_fence(challenge$sample),
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
