#' Record one provisioning step's outcome
#' @keywords internal
#' @noRd
provision_step <- function(step, status, detail) {
  data.frame(
    step = step,
    status = status,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

#' Run one provisioning step, turning a failure into a reported row
#'
#' A chapter's infrastructure is several independent systems. One of
#' them being down is not a reason to leave the others unprovisioned,
#' so a step that errors is recorded and the run carries on.
#'
#' @param step Step label.
#' @param action Function of no arguments returning a detail string.
#' @return A one-row data frame as [provision_step()] returns.
#' @keywords internal
#' @noRd
provision_try <- function(step, action) {
  tryCatch(
    provision_step(step, "done", action()),
    error = function(cnd) {
      cli::cli_alert_warning("{step} failed: {conditionMessage(cnd)}")
      provision_step(step, "failed", conditionMessage(cnd))
    }
  )
}

#' Whether a checklist item is already ticked
#' @keywords internal
#' @noRd
provision_is_done <- function(state, pattern) {
  if (!nrow(state)) {
    return(FALSE)
  }
  matched <- grepl(pattern, state$item, fixed = TRUE)
  any(matched) && all(state$done[matched])
}

#' Set up everything a new chapter's infrastructure needs
#'
#' One command for the steps jinx can do by itself, read off the
#' onboarding issue: the website entry, the chapter's GitHub team, and
#' optionally its presentations repository and Meetup group photo.
#'
#' Details come from the issue's machine-readable block and from the
#' conversation on it - the Meetup group URL the Meetup Pro team posts
#' is what makes the team slug derivable, so steps that need it are
#' reported as waiting until that comment exists rather than guessed at.
#'
#' Re-running is safe and expected: every step checks for its own work
#' first, so the command can be run again as the thread fills in. The
#' chapter mailbox is deliberately not included - it needs its own
#' approval comment, via [chapter_email_provision()].
#'
#' @param issue_number Onboarding issue number.
#' @param presentations_repo Whether to create the chapter's
#'   presentations repository. Opt-in: not every chapter wants one.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @param website_repo Website repository name.
#' @return A data frame with columns `step`, `status`, and `detail`,
#'   invisibly.
#' @export
chapter_provision <- function(
  issue_number,
  presentations_repo = FALSE,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  website_repo = "rladies.github.io"
) {
  meta <- chapter_meta_fetch(issue_number, org, onboarding_repo)
  if (is.null(meta$city) || is.null(meta$country)) {
    cli::cli_abort(c(
      "Issue #{issue_number} carries no readable chapter details.",
      "i" = "Only issues jinx opened can be provisioned from."
    ))
  }

  found <- chapter_thread_scan(issue_number, org, onboarding_repo)
  state <- chapter_onboard_state(issue_number, org, onboarding_repo)
  steps <- list()

  steps[[1]] <- if (
    provision_is_done(state, "chapter to the current chapters on the website")
  ) {
    provision_step("Website entry", "skipped", "already on the website")
  } else {
    provision_try("Website entry", function() {
      url <- chapter_onboard_website(
        issue_number = issue_number,
        org = org,
        onboarding_repo = onboarding_repo,
        website_repo = website_repo
      )
      paste0("opened ", url)
    })
  }

  steps[[2]] <- if (is.null(found$urlname)) {
    provision_step(
      "GitHub team",
      "waiting",
      "no Meetup group on this issue yet"
    )
  } else {
    provision_try("GitHub team", function() {
      slug <- chapter_team_create(
        urlname = found$urlname,
        city = meta$city,
        country = meta$country,
        region = meta$region,
        org = org
      )
      paste0("`@", org, "/", slug, "`")
    })
  }

  steps[[3]] <- if (!isTRUE(presentations_repo)) {
    provision_step(
      "Presentations repo",
      "skipped",
      "opt-in; ask for it with `repo`"
    )
  } else if (is.null(found$urlname)) {
    provision_step(
      "Presentations repo",
      "waiting",
      "no Meetup group on this issue yet"
    )
  } else {
    provision_try("Presentations repo", function() {
      repo <- chapter_repo_create(
        team_slug = chapter_team_slug(found$urlname),
        city = meta$city,
        country = meta$country,
        region = meta$region,
        org = org
      )
      paste0("`", org, "/", repo, "`")
    })
  }

  steps[[4]] <- if (is.null(found$urlname)) {
    provision_step(
      "Meetup photo",
      "waiting",
      "no Meetup group on this issue yet"
    )
  } else {
    provision_try("Meetup photo", function() {
      chapter_meetup_logo_upload(found$urlname)
      paste0("logo set on `", found$urlname, "`")
    })
  }

  report <- do.call(rbind, steps)

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    chapter_provision_report(report, meta, found)
  )

  invisible(report)
}

#' Render a provisioning run as a comment
#'
#' @param report Step table from [chapter_provision()].
#' @param meta Chapter details from the issue block.
#' @param found Facts read off the thread by [chapter_thread_scan()].
#' @return Markdown body as a single string.
#' @keywords internal
#' @noRd
chapter_provision_report <- function(report, meta, found) {
  icons <- c(
    done = "\u2705",
    skipped = "\u27a1\ufe0f",
    waiting = "\u23f3",
    failed = "\u274c"
  )
  lines <- glue::glue_data(
    report,
    "| {icons[status]} | {step} | {detail} |"
  )

  waiting <- any(report$status == "waiting")
  failed <- any(report$status == "failed")

  footer <- if (failed) {
    paste0(
      "Some steps failed. Fix the cause and run `/jinx chapter-provision ",
      "<issue>` again - the steps that worked are not repeated."
    )
  } else if (waiting) {
    paste0(
      "Waiting on the Meetup group. Once the Meetup Pro team posts the ",
      "group URL here, run `/jinx chapter-provision <issue>` again and ",
      "the remaining steps will pick it up."
    )
  } else {
    "That is everything jinx can set up on its own."
  }

  paste0(
    "## Infrastructure for ",
    meta$city,
    ", ",
    meta$country,
    "\n\n",
    "| | Step | Detail |\n| --- | --- | --- |\n",
    paste(lines, collapse = "\n"),
    "\n\n",
    if (!is.null(found$email)) {
      paste0("Chapter mailbox on file: `", found$email, "`\n\n")
    },
    footer
  )
}
