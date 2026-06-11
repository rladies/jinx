#' Create a new chapter setup issue
#'
#' Opens a tracking issue in the new-chapters-onboarding repo with
#' the full checklist for setting up a new RLadies+ chapter.
#'
#' @param city Chapter city name.
#' @param country Chapter country.
#' @param organizers Character vector of organizer names.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository for chapter onboarding issues.
#' @return Issue URL (invisibly).
#' @export
chapter_create_setup <- function(
  city,
  country,
  organizers,
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

  issue <- gh::gh(
    "POST /repos/{owner}/{repo}/issues",
    owner = org,
    repo = onboarding_repo,
    title = glue::glue("{city}, {country} chapter setup"),
    body = body,
    labels = list("new chapter")
  )

  review_assign_onboarding(org, onboarding_repo, issue$number)

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

#' Create a chapter JSON PR on the website repo
#'
#' Generates the chapter JSON file and creates a PR to add it to the website.
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province (optional).
#' @param meetup_urlname Meetup group URL name.
#' @param email Chapter email address.
#' @param organizers Character vector of organizer names.
#' @param status Chapter status. Defaults to `"prospective"`.
#' @param social_media Named list of social media handles (optional).
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param website_repo Website repository name.
#' @return PR URL (invisibly).
#' @export
chapter_create_pr <- function(
  city,
  country,
  region = NULL,
  meetup_urlname,
  email,
  organizers,
  status = "prospective",
  social_media = list(),
  org = "rladies",
  website_repo = "rladies.github.io"
) {
  slug <- tolower(gsub("[^a-z0-9]+", "-", tolower(city), perl = TRUE))
  country_slug <- tolower(gsub(
    "[^a-z0-9]+",
    "-",
    tolower(country),
    perl = TRUE
  ))

  filename <- if (!is.null(region)) {
    region_slug <- tolower(gsub(
      "[^a-z0-9]+",
      "-",
      tolower(region),
      perl = TRUE
    ))
    glue::glue("{country_slug}-{region_slug}-{slug}.json")
  } else {
    glue::glue("{country_slug}-{slug}.json")
  }

  socials <- c(
    list(meetup = meetup_urlname, email = email),
    social_media
  )

  chapter_data <- list(
    urlname = meetup_urlname,
    status = jsonlite::unbox(status),
    country = jsonlite::unbox(country),
    city = jsonlite::unbox(city),
    social_media = socials,
    organizers = list(current = organizers)
  )

  if (!is.null(region)) {
    chapter_data[["state.region"]] <- jsonlite::unbox(region)
  }

  json_content <- jsonlite::toJSON(
    chapter_data,
    pretty = TRUE,
    auto_unbox = FALSE
  )
  content_b64 <- jsonlite::base64_enc(charToRaw(as.character(json_content)))

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
    body = glue::glue(
      "Adding new chapter entry for **{city}, {country}**.\n\n",
      "- Status: {status}\n",
      "- Meetup: {meetup_urlname}\n",
      "- Organizers: {paste(organizers, collapse = ', ')}\n\n",
      "_Created by jinx_"
    )
  )

  cli::cli_alert_success("Chapter PR created: {url}")
  invisible(url)
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
