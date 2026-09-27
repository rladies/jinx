#' Airtable base holding organiser form submissions
#' @keywords internal
#' @noRd
organiser_form_base <- function() {
  env_default("AIRTABLE_ORGANISER_BASE", "appM6GuE0Jl1UI9qx")
}

#' Airtable table holding organiser form submissions
#' @keywords internal
#' @noRd
organiser_form_table <- function() {
  env_default("AIRTABLE_ORGANISER_TABLE", "tblU3jxWDxrv8QaVa")
}

#' Link to one organiser form submission
#'
#' The team needs the submitter's email to send the Slack invite, and
#' this links them to it rather than reprinting it on a GitHub issue.
#'
#' @param record_id Airtable record id.
#' @return A URL.
#' @keywords internal
#' @noRd
organiser_form_url <- function(record_id) {
  paste0(
    "https://airtable.com/",
    organiser_form_base(),
    "/",
    organiser_form_table(),
    "/",
    record_id
  )
}

#' Find organiser form submissions for a chapter
#'
#' The form's `chapter` field is free text and inconsistently written -
#' "Cologne, Germany" beside "Wake Forest, North Carolina EE.UU" - so
#' matching is by city slug appearing anywhere in it, and the caller is
#' expected to show a human what was found rather than act on it.
#'
#' @param city Chapter city.
#' @param api_key Airtable API key.
#' @return A data frame with `record_id`, `name`, `chapter`, `status`,
#'   and `type`; empty when nothing matches.
#' @export
chapter_organiser_submissions <- function(
  city,
  api_key = Sys.getenv("AIRTABLE_API_KEY")
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY is not set")
  }
  wanted <- chapter_slug(city)
  if (!nzchar(wanted)) {
    cli::cli_abort("Cannot look up submissions without a city")
  }

  records <- airtable_list_records(
    organiser_form_base(),
    organiser_form_table(),
    api_key = api_key
  )

  rows <- lapply(records, function(rec) {
    fields <- rec$fields %or% list()
    chapter <- fields$chapter %or% ""
    if (!grepl(wanted, chapter_slug(chapter), fixed = TRUE)) {
      return(NULL)
    }
    data.frame(
      record_id = rec$id %or% NA_character_,
      name = fields$name %or% NA_character_,
      chapter = chapter,
      status = fields$status %or% NA_character_,
      type = fields$type %or% NA_character_,
      stringsAsFactors = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(chapter_submissions_empty())
  }
  do.call(rbind, rows)
}

chapter_submissions_empty <- function() {
  data.frame(
    record_id = character(0),
    name = character(0),
    chapter = character(0),
    status = character(0),
    type = character(0),
    stringsAsFactors = FALSE
  )
}

#' The comment prompting the organiser Slack invite
#'
#' Slack has no API for inviting someone to a workspace outside an
#' Enterprise plan, so a human does the invite from workspace settings.
#' jinx's job is to say when the form has arrived, point at it, and stop
#' the step being forgotten.
#'
#' @param submissions Data frame from [chapter_organiser_submissions()].
#' @param city Chapter city.
#' @param issue_number Onboarding issue number, for the confirm command.
#' @return Markdown body as a single string.
#' @keywords internal
#' @noRd
chapter_slack_prompt_body <- function(submissions, city, issue_number) {
  if (nrow(submissions) == 0) {
    return(glue::glue(
      "## Organisers Slack invite: {city}\n\n",
      "No organiser form submission found for **{city}** yet, so the ",
      "Organisers Slack invite is not ready to send. The form is at ",
      "<https://rladies.org/form/organiser>.\n"
    ))
  }

  bullets <- vapply(
    seq_len(nrow(submissions)),
    function(i) {
      r <- submissions[i, ]
      glue::glue(
        "- **{r$name}** - {r$chapter} ({r$type %or% 'type not set'}, ",
        "{r$status %or% 'no status'}) - ",
        "[open the submission]({organiser_form_url(r$record_id)})"
      )
    },
    character(1)
  )

  glue::glue(
    "## Organisers Slack invite: {city}\n\n",
    "{nrow(submissions)} organiser form submission",
    "{if (nrow(submissions) == 1) '' else 's'} found:\n\n",
    "{paste(bullets, collapse = '\n')}\n\n",
    "Slack has no API for workspace invites outside an Enterprise plan, ",
    "so this one is by hand: open the submission for the email address, ",
    "then invite them from the Organisers workspace settings.\n\n",
    "Run `/jinx chapter-slack-sent {issue_number}` once the invite has ",
    "gone out ",
    "and the checklist step will be ticked.\n\n",
    "Email addresses are deliberately not repeated here - the link goes ",
    "to the record that holds them.\n"
  )
}

#' Prompt the onboarding issue for the organiser Slack invite
#'
#' @param issue_number Onboarding issue number.
#' @param city Chapter city. Read from the issue when `NULL`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The posted body (invisibly).
#' @export
chapter_slack_prompt <- function(
  issue_number,
  city = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  details <- chapter_meta_complete(
    list(city = city),
    issue_number,
    org,
    onboarding_repo,
    needed = "city"
  )
  if (is.null(details$city)) {
    cli::cli_abort(c(
      "Cannot look for organiser submissions without a city.",
      "i" = "Issue #{issue_number} carries no jinx block; pass {.arg city}."
    ))
  }

  submissions <- chapter_organiser_submissions(details$city)
  body <- chapter_slack_prompt_body(submissions, details$city, issue_number)
  announce_post_reply(org, onboarding_repo, issue_number, body)
  invisible(body)
}

#' Record that the organisers Slack invite was sent
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return `TRUE` when the checklist step was ticked.
#' @export
chapter_slack_sent <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  chapter_checklist_tick(
    issue_number,
    "invite organizers to the RLadies\\+ Organizers Slack",
    org = org,
    onboarding_repo = onboarding_repo
  )
}
