#' Find the open onboarding issue for a chapter
#'
#' Matches on the issue title, which onboarding issues open as
#' "<City>, <Country> chapter setup".
#'
#' @param city Chapter city.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The issue number, or `NULL` when no open issue matches.
#' @export
chapter_find_issue <- function(
  city,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  issues <- gh::gh(
    "GET /repos/{owner}/{repo}/issues",
    owner = org,
    repo = onboarding_repo,
    state = "open",
    .limit = Inf
  )
  wanted <- chapter_slug(city)
  for (issue in issues) {
    if (identical(chapter_slug(sub(",.*$", "", issue$title)), wanted)) {
      return(issue$number)
    }
  }
  NULL
}

#' Report the state of a chapter onboarding
#'
#' Accepts either an issue number or a city name, and renders the
#' checklist summary that `/jinx chapter-status` replies with.
#'
#' @param ref Issue number, or a city name to look one up by.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return Markdown body as a single string.
#' @export
chapter_status_report <- function(
  ref,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  issue_number <- chapter_resolve_ref(ref, org, onboarding_repo)
  if (is.null(issue_number)) {
    return(glue::glue("No open onboarding issue found for **{ref}**."))
  }

  state <- chapter_onboard_state(issue_number, org, onboarding_repo)
  summary <- chapter_onboard_summary(
    state,
    title = glue::glue(
      "Onboarding status: {org}/{onboarding_repo}#{issue_number}"
    )
  )
  summary
}

#' Resolve a status reference to an issue number
#' @keywords internal
#' @noRd
chapter_resolve_ref <- function(ref, org, onboarding_repo) {
  if (grepl("^[0-9]+$", as.character(ref))) {
    return(as.integer(ref))
  }
  chapter_find_issue(ref, org, onboarding_repo)
}

#' Nudge the team holding up a stale chapter onboarding
#'
#' Finds open onboarding issues with no activity for `days` days and
#' comments on each, naming the team that owns the first unchecked step
#' rather than pinging everyone. Onboardings stall on the email and
#' Meetup Pro teams more than anywhere else, so the ping is targeted.
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @param days Days without activity before nudging. Defaults to 14.
#' @param labels Issue labels to consider.
#' @return Invisibly, a list of the issues nudged.
#' @export
chapter_remind_stale <- function(
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  days = 14,
  labels = c("new chapter", "chapter update")
) {
  cutoff <- Sys.Date() - days
  nudged <- list()

  for (label in labels) {
    issues <- gh::gh(
      "GET /repos/{owner}/{repo}/issues",
      owner = org,
      repo = onboarding_repo,
      labels = label,
      state = "open",
      sort = "updated",
      direction = "asc",
      .limit = Inf
    )
    for (issue in issues) {
      result <- chapter_nudge_issue(issue, cutoff, days, org, onboarding_repo)
      if (!is.null(result)) {
        nudged[[length(nudged) + 1]] <- result
      }
    }
  }

  cli::cli_alert_info("Nudged {length(nudged)} stale onboarding issue{?s}")
  invisible(nudged)
}

#' Nudge one issue if it is stale, otherwise do nothing
#' @keywords internal
#' @noRd
chapter_nudge_issue <- function(issue, cutoff, days, org, onboarding_repo) {
  updated <- as.Date(sub("T.*", "", issue$updated_at))
  if (updated > cutoff) {
    return(NULL)
  }

  state <- chapter_checklist_parse(issue$body)
  if (nrow(state) > 0 && all(state$done)) {
    return(NULL)
  }

  announce_post_reply(
    org,
    onboarding_repo,
    issue$number,
    chapter_nudge_body(state, days)
  )
  list(number = issue$number, title = issue$title, url = issue$html_url)
}

#' The nudge comment for a stale onboarding issue
#' @keywords internal
#' @noRd
chapter_nudge_body <- function(state, days) {
  blocker <- chapter_onboard_blocker(state)
  who <- if (is.na(blocker)) "the onboarding team" else paste0("@", blocker)
  pending <- state[!state$done, ]
  next_step <- if (nrow(pending) == 0) {
    "the remaining steps"
  } else {
    pending$item[1]
  }

  glue::glue(
    "No activity on this onboarding for {days} days.\n\n",
    "Waiting on {who}: {next_step}\n\n",
    "If this is blocked on something outside the checklist, say so here ",
    "so the onboarding team can help."
  )
}
