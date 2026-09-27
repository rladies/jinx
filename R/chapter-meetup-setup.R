#' The Meetup URL name for a chapter
#'
#' `meetup.com/rladies-<city>`, hyphenated for multi-word cities and
#' transliterated the way the website filenames already are. This value
#' and the group name cannot be changed after the group is created, so
#' getting them right first time is the whole point of rendering them
#' here rather than having someone type them.
#'
#' @param city Chapter city.
#' @return The urlname, without the meetup.com prefix.
#' @export
chapter_meetup_urlname <- function(city) {
  slug <- chapter_slug(city)
  if (!nzchar(slug)) {
    cli::cli_abort("Cannot build a Meetup urlname from {.val {city}}")
  }
  paste0("rladies-", slug)
}

#' The Meetup group name for a chapter
#'
#' @param city Chapter city, used as written apart from trimming.
#' @return The group name.
#' @export
chapter_meetup_name <- function(city) {
  city <- trimws(city %or% "")
  if (!nzchar(city)) {
    cli::cli_abort("Cannot build a Meetup group name without a city")
  }
  paste("RLadies+", city)
}

#' Whether a Meetup urlname looks taken
#'
#' Advisory only. Meetup serves its single-page app with HTTP 200 for
#' groups that do not exist, so the status code says nothing; the check
#' looks for the "Group not found" copy in the body instead. That copy
#' can change, so this reports `"unknown"` rather than guessing when it
#' cannot tell, and a human should confirm before creating the group.
#'
#' @param urlname Meetup urlname to check.
#' @return One of `"available"`, `"taken"`, or `"unknown"`.
#' @export
meetup_urlname_status <- function(urlname) {
  body <- tryCatch(
    httr2::request("https://www.meetup.com") |>
      httr2::req_url_path_append(urlname) |>
      httr2::req_user_agent(meetup_user_agent()) |>
      httr2::req_perform() |>
      httr2::resp_body_string(),
    error = function(e) NULL
  )

  if (is.null(body) || !nzchar(body)) {
    return("unknown")
  }
  if (grepl("Group not found", body, fixed = TRUE)) {
    return("available")
  }
  "taken"
}

meetup_user_agent <- function() {
  "jinx chapter onboarding (https://github.com/rladies/jinx)"
}

#' Render the Meetup setup brief for a chapter
#'
#' Everything the Meetup Pro team needs in one comment: the exact group
#' name and URL, the settings the organisational guidelines call for, and
#' the standard description ready to paste.
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param status Result of [meetup_urlname_status()], or `NULL` to skip
#'   the availability line.
#' @return Markdown body as a single string.
#' @export
chapter_meetup_brief <- function(city, country, status = NULL) {
  urlname <- chapter_meetup_urlname(city)

  glue::glue(
    "## Meetup setup: {chapter_meetup_name(city)}\n\n",
    "**Name and URL cannot be changed after creation**, so they are ",
    "spelled out here rather than retyped.\n\n",
    "| Field | Value |\n",
    "| ----- | ----- |\n",
    "| Group name | `{chapter_meetup_name(city)}` |\n",
    "| URL | `https://www.meetup.com/{urlname}/` |\n",
    "| Hometown | {city}, {country} |\n",
    "| Category | Technology, or Data Science |\n",
    "| Member label | RLadies+ |\n",
    "| Topics | R Project for Statistical Computing; ",
    "Data Science using R |\n\n",
    "{meetup_status_line(status, urlname)}",
    "\nThe URL follows the `rladies-<city>` convention. A chapter can ask ",
    "for something else where a local abbreviation is what people ",
    "actually use - `rladies-pdx` for Portland, say - but it still ",
    "cannot be changed afterwards.\n",
    "\n### Description, ready to paste\n\n",
    "The mission text, the code of conduct link and the photography ",
    "notice must all stay. Organisers may translate or adapt the rest.\n\n",
    "```\n{meetup_description_text()}\n```\n\n",
    "### After creating it\n\n",
    "- Post the group URL back on this issue.\n",
    "- Set the group photo by running `/jinx chapter-meetup-logo ",
    "<urlname>`, which uploads the RLadies+ social profile logo.\n",
    "- Ask the organisers to join, then change their role to ",
    "co-organiser.\n",
    "- Co-organisers must not be cis men.\n"
  )
}

#' The availability line for the brief
#' @keywords internal
#' @noRd
meetup_status_line <- function(status, urlname) {
  if (is.null(status)) {
    return("")
  }
  text <- switch(
    status,
    available = glue::glue(
      "`{urlname}` looks free. Worth a glance before creating it - ",
      "this check reads Meetup's page copy, not an API."
    ),
    taken = glue::glue(
      "**`{urlname}` looks taken.** Check before creating it; a ",
      "reactivation or a name clash needs the Meetup Pro account ",
      "manager."
    ),
    glue::glue(
      "Could not tell whether `{urlname}` is free - check by hand."
    )
  )
  paste0(text, "\n")
}

#' The standard description text
#' @keywords internal
#' @noRd
meetup_description_text <- function() {
  path <- system.file("templates", "meetup-description.md", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("Meetup description template not found in jinx")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Post the Meetup setup brief on an onboarding issue
#'
#' Reads the chapter from the issue's own machine-readable block, so in
#' the usual case only the issue number is needed.
#'
#' @param issue_number Onboarding issue number.
#' @param city Chapter city. Read from the issue when `NULL`.
#' @param country Chapter country. Read from the issue when `NULL`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The rendered brief (invisibly).
#' @export
chapter_meetup_request <- function(
  issue_number,
  city = NULL,
  country = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  details <- chapter_meta_complete(
    list(city = city, country = country),
    issue_number,
    org,
    onboarding_repo,
    needed = c("city", "country")
  )
  if (is.null(details$city) || is.null(details$country)) {
    cli::cli_abort(c(
      "Cannot render a Meetup brief without a city and country.",
      "i" = "Issue #{issue_number} carries no jinx block; pass them."
    ))
  }

  urlname <- chapter_meetup_urlname(details$city)
  body <- chapter_meetup_brief(
    details$city,
    details$country,
    status = meetup_urlname_status(urlname)
  )

  announce_post_reply(org, onboarding_repo, issue_number, body)
  invisible(body)
}
