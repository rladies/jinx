#' Tick a checklist item in an issue body
#'
#' Finds the first unchecked task-list line containing `pattern` and
#' ticks it. Returns `NULL` when nothing matches, so callers can tell a
#' no-op from a change.
#'
#' @param body Issue body markdown.
#' @param pattern Text to look for in the item, matched case-insensitively.
#' @return The updated body, or `NULL` when no unchecked item matched.
#' @keywords internal
#' @noRd
checklist_tick_body <- function(body, pattern) {
  lines <- strsplit(body %or% "", "\n", fixed = TRUE)[[1]]
  unchecked <- grepl("^\\s*[-*]\\s+\\[ \\]", lines, perl = TRUE)
  hit <- unchecked & grepl(pattern, lines, ignore.case = TRUE, fixed = FALSE)
  if (!any(hit)) {
    return(NULL)
  }
  first <- which(hit)[1]
  lines[first] <- sub("\\[ \\]", "[x]", lines[first])
  paste(lines, collapse = "\n")
}

#' Tick a checklist item on an onboarding issue
#'
#' @param issue_number Onboarding issue number.
#' @param pattern Text identifying the item to tick.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return `TRUE` when an item was ticked, `FALSE` otherwise.
#' @export
chapter_checklist_tick <- function(
  issue_number,
  pattern,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  issue <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number
  )

  updated <- checklist_tick_body(issue$body, pattern)
  if (is.null(updated)) {
    cli::cli_alert_info("No unchecked item matching {.val {pattern}}")
    return(FALSE)
  }

  gh::gh(
    "PATCH /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number,
    body = updated
  )
  cli::cli_alert_success("Ticked {.val {pattern}} on issue #{issue_number}")
  TRUE
}

#' Add a prospective chapter to the website from its onboarding issue
#'
#' Opens the website PR with the chapter's prospective entry, requests
#' review from the leadership team, links the PR on the onboarding
#' issue, and ticks the website step of the checklist.
#'
#' A prospective entry deliberately carries no chapter email and no
#' Meetup group: neither exists at this point in onboarding, and the
#' entry is filled in as those steps complete.
#'
#' Anything left `NULL` is read from the issue's own machine-readable
#' block, so in the usual case only the issue number is needed.
#'
#' @param issue_number Onboarding issue number.
#' @param city Chapter city. Read from the issue when `NULL`.
#' @param country Chapter country. Read from the issue when `NULL`.
#' @param region State/region/province. Read from the issue when `NULL`.
#' @param organizers Character vector of organizer names. Read from the
#'   issue when `NULL`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @param website_repo Website repository name.
#' @return The website PR URL (invisibly).
#' @export
chapter_onboard_website <- function(
  issue_number,
  city = NULL,
  country = NULL,
  region = NULL,
  organizers = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  website_repo = "rladies.github.io"
) {
  details <- chapter_meta_complete(
    list(
      city = city,
      country = country,
      region = region,
      organizers = organizers
    ),
    issue_number,
    org,
    onboarding_repo
  )
  if (is.null(details$city) || is.null(details$country)) {
    cli::cli_abort(c(
      "Cannot add a chapter to the website without a city and country.",
      "i" = "Issue #{issue_number} carries no jinx block; pass them explicitly."
    ))
  }
  city <- details$city
  country <- details$country

  url <- chapter_create_pr(
    city = city,
    country = country,
    region = details$region,
    organizers = details$organizers %or% character(0),
    status = "prospective",
    org = org,
    website_repo = website_repo
  )

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    glue::glue(
      "Added **{city}, {country}** to the website as a prospective ",
      "chapter: {url}\n\n",
      "Review has been requested from @{org}/leadership. The chapter ",
      "email and Meetup group get added to this entry once those steps ",
      "are done."
    )
  )

  chapter_checklist_tick(
    issue_number,
    "chapter to the current chapters on the website",
    org = org,
    onboarding_repo = onboarding_repo
  )

  invisible(url)
}
