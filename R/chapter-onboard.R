#' Create a new chapter setup issue
#'
#' Opens a tracking issue in the new-chapters-onboarding repo with
#' the full checklist for setting up a new RLadies+ chapter.
#'
#' @param city Chapter city name.
#' @param country Chapter country.
#' @param organizers Character vector of organizer names.
#' @param region State/region/province, or `NULL`. Used to narrow the
#'   duplicate check's proximity search.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository for chapter onboarding issues.
#' @return Issue URL (invisibly).
#' @export
chapter_create_setup <- function(
  city,
  country,
  organizers,
  region = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  body <- render_template(
    system.file("templates", "chapter-setup.md", package = "jinx"),
    list(
      CITY = city,
      COUNTRY = country,
      ORGANIZERS = toString(organizers)
    )
  )
  body <- paste0(
    body,
    "\n\n",
    chapter_meta_render(city, country, region, organizers)
  )

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = onboarding_repo,
    title = glue::glue("{city}, {country} chapter setup"),
    body = body,
    labels = list("new chapter")
  )

  review_assign_onboarding(org, onboarding_repo, issue$number)
  chapter_duplicate_comment(
    issue_number = issue$number,
    city = city,
    country = country,
    region = region,
    org = org,
    onboarding_repo = onboarding_repo
  )

  cli::cli_alert_success("Chapter setup issue created: {issue$html_url}")
  invisible(issue$html_url)
}

#' Create a chapter update issue
#'
#' Opens a tracking issue for updating an existing chapter's infrastructure.
#'
#' @param city Chapter city name.
#' @param country Chapter country.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository for chapter onboarding issues.
#' @return Issue URL (invisibly).
#' @export
chapter_create_update <- function(
  city,
  country,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  body <- render_template(
    system.file("templates", "chapter-update.md", package = "jinx"),
    list(CITY = city, COUNTRY = country)
  )

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = onboarding_repo,
    title = glue::glue("{city}, {country} chapter update"),
    body = body,
    labels = list("chapter update")
  )

  review_assign_onboarding(org, onboarding_repo, issue$number)

  cli::cli_alert_success("Chapter update issue created: {issue$html_url}")
  invisible(issue$html_url)
}

#' Build the website JSON for a chapter
#'
#' Matches the shape of the entries already in `data/chapters`: a
#' prospective chapter carries no `urlname` and an empty `social_media`
#' object, because it has neither a Meetup group nor a chapter email
#' yet.
#'
#' @inheritParams chapter_create_pr
#' @return A JSON string.
#' @keywords internal
#' @noRd
chapter_entry_json <- function(
  city,
  country,
  region = NULL,
  meetup_urlname = NULL,
  email = NULL,
  organizers = character(0),
  status = "prospective",
  social_media = list()
) {
  socials <- c(
    if (!is.null(meetup_urlname)) list(meetup = meetup_urlname),
    if (!is.null(email)) list(email = email),
    social_media
  )
  socials <- lapply(socials, jsonlite::unbox)
  if (length(socials) == 0) {
    socials <- structure(list(), names = character(0))
  }

  entry <- c(
    if (!is.null(meetup_urlname)) {
      list(urlname = jsonlite::unbox(meetup_urlname))
    },
    list(
      status = jsonlite::unbox(status),
      country = jsonlite::unbox(country)
    ),
    if (!is.null(region)) list("state.region" = jsonlite::unbox(region)),
    list(
      city = jsonlite::unbox(city),
      social_media = socials,
      organizers = list(current = as.character(organizers), former = list())
    )
  )

  as.character(jsonlite::toJSON(entry, pretty = TRUE, auto_unbox = FALSE))
}

#' Check a chapter entry against the bundled schema
#'
#' @param json A JSON string.
#' @return `TRUE`, invisibly; aborts with the schema errors otherwise.
#' @keywords internal
#' @noRd
chapter_entry_validate <- function(json) {
  schema <- system.file("schemas", "chapter.json", package = "jinx")
  if (!nzchar(schema)) {
    cli::cli_abort("Chapter schema not found in jinx package")
  }
  valid <- jsonvalidate::json_validate(json, schema, verbose = TRUE)
  if (!isTRUE(valid)) {
    cli::cli_abort(c(
      "Generated chapter entry does not match the schema:",
      "x" = paste(attr(valid, "errors")$message, collapse = "; ")
    ))
  }
  invisible(TRUE)
}

#' Create a chapter JSON PR on the website repo
#'
#' Generates the chapter JSON entry, validates it against the bundled
#' schema, and opens a PR adding it to the website. A prospective
#' chapter has no Meetup group or chapter email yet, so both are
#' optional and are simply left out of the entry.
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province (optional).
#' @param meetup_urlname Meetup group URL name, or `NULL` when the group
#'   does not exist yet.
#' @param email Chapter email address, or `NULL` when it does not exist
#'   yet.
#' @param organizers Character vector of organizer names.
#' @param status Chapter status. Defaults to `"prospective"`.
#' @param social_media Named list of social media handles (optional).
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param website_repo Website repository name.
#' @param team_reviewers Teams to request review from. Defaults to
#'   `"leadership"`, which the onboarding process requires.
#' @return PR URL (invisibly).
#' @export
chapter_create_pr <- function(
  city,
  country,
  region = NULL,
  meetup_urlname = NULL,
  email = NULL,
  organizers = character(0),
  status = "prospective",
  social_media = list(),
  org = "rladies",
  website_repo = "rladies.github.io",
  team_reviewers = "leadership"
) {
  slug <- chapter_slug(city)
  filename <- chapter_filename(city, country, region)

  json_content <- chapter_entry_json(
    city = city,
    country = country,
    region = region,
    meetup_urlname = meetup_urlname,
    email = email,
    organizers = organizers,
    status = status,
    social_media = social_media
  )
  chapter_entry_validate(json_content)

  content_b64 <- jsonlite::base64_enc(charToRaw(json_content))

  branch <- glue::glue("chapter/{slug}")
  gh_branch_upsert(org, website_repo, branch, force = FALSE)

  gh::gh(
    "PUT /repos/{owner}/{repo}/contents/data/chapters/{filename}",
    owner = org,
    repo = website_repo,
    path = glue::glue("data/chapters/{filename}"),
    message = glue::glue("Add {city}, {country} chapter"),
    content = content_b64,
    branch = branch
  )

  url <- gh_open_or_update_pr(
    org,
    website_repo,
    branch,
    title = glue::glue("Add chapter: {city}, {country}"),
    body = chapter_pr_body(city, country, status, meetup_urlname, organizers),
    team_reviewers = team_reviewers
  )

  cli::cli_alert_success("Chapter PR created: {url}")
  invisible(url)
}

#' Body text for a chapter entry PR
#' @keywords internal
#' @noRd
chapter_pr_body <- function(city, country, status, meetup_urlname, organizers) {
  organiser_line <- if (length(organizers) == 0) {
    "- Organizers: to be confirmed\n"
  } else {
    glue::glue("- Organizers: {paste(organizers, collapse = ', ')}\n")
  }
  meetup_line <- if (is.null(meetup_urlname)) {
    "- Meetup: not created yet\n"
  } else {
    glue::glue("- Meetup: {meetup_urlname}\n")
  }

  glue::glue(
    "Adding new chapter entry for **{city}, {country}**.\n\n",
    "- Status: {status}\n",
    meetup_line,
    organiser_line,
    "\n_Created by jinx_"
  )
}

review_assign_onboarding <- function(org, repo, issue_number) {
  config <- load_teams_config()
  team <- config$teams[["chapter-onboarding"]]

  if (!is.null(team) && !is.null(team$notify_teams)) {
    for (notify_team in team$notify_teams) {
      tryCatch(
        gh::gh(
          "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
          owner = org,
          repo = repo,
          issue_number = issue_number,
          body = glue::glue("cc @{org}/{notify_team}")
        ),
        error = function(e) {
          cli::cli_alert_warning(paste0(
            "Failed to notify @{org}/{notify_team} on ",
            "issue #{issue_number}: {e$message}"
          ))
        }
      )
    }
  }
}
