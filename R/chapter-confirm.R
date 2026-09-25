#' Render the onboarding confirmation email
#'
#' @param city Chapter city.
#' @param email Chapter email address, or `NULL` when it does not exist
#'   yet.
#' @param meetup_url Meetup group URL, or `NULL`.
#' @return The email body as a single string.
#' @keywords internal
#' @noRd
chapter_confirm_body <- function(city, email = NULL, meetup_url = NULL) {
  render_template(
    system.file("templates", "chapter-confirmed.md", package = "jinx"),
    list(
      CITY = city,
      EMAIL = email %or% "not set up yet",
      MEETUP_URL = meetup_url %or% "not created yet"
    )
  )
}

#' Which checklist steps are still outstanding
#'
#' @param state Data frame from [chapter_onboard_state()].
#' @return Character vector of unchecked item texts.
#' @keywords internal
#' @noRd
chapter_outstanding_items <- function(state) {
  if (nrow(state) == 0) {
    return(character(0))
  }
  state$item[!state$done]
}

#' Confirm a completed onboarding to the chapter organisers
#'
#' Sends the confirmation email from `jinx@rladies.org`, cc'ing
#' `chapters@rladies.org` so the onboarding inbox keeps the thread, and
#' notes on the issue that it went out.
#'
#' Refuses to send while checklist steps are outstanding, since the email
#' tells the organisers their chapter is set up. Pass `force = TRUE` to
#' override, which is occasionally right - a step may be recorded
#' elsewhere - but it should be a decision rather than an accident.
#'
#' Recipient addresses are passed in rather than read from the issue:
#' organiser emails are deliberately not stored in the issue metadata,
#' and this function does not put them back there either. The issue
#' comment records how many organisers were written to, not who.
#'
#' @param issue_number Onboarding issue number.
#' @param to Organiser email addresses.
#' @param city Chapter city. Read from the issue when `NULL`.
#' @param email Chapter email address to quote in the message.
#' @param meetup_url Meetup URL to quote in the message.
#' @param force Send even with checklist steps outstanding.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The sent message id (invisibly).
#' @export
chapter_confirm_send <- function(
  issue_number,
  to,
  city = NULL,
  email = NULL,
  meetup_url = NULL,
  force = FALSE,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  to <- to[nzchar(to %or% "")]
  invalid <- to[!vapply(to, is_valid_email, logical(1))]
  if (length(to) == 0 || length(invalid) > 0) {
    cli::cli_abort(c(
      "Need at least one valid organiser address to confirm to.",
      "x" = if (length(invalid) > 0) {
        "Not an email address: {.val {invalid}}"
      }
    ))
  }

  details <- chapter_meta_complete(
    list(city = city),
    issue_number,
    org,
    onboarding_repo,
    needed = "city"
  )
  if (is.null(details$city)) {
    cli::cli_abort(c(
      "Cannot confirm without knowing the chapter.",
      "i" = "Issue #{issue_number} carries no jinx block; pass {.arg city}."
    ))
  }

  outstanding <- chapter_outstanding_items(
    chapter_onboard_state(issue_number, org, onboarding_repo)
  )
  if (length(outstanding) > 0 && !isTRUE(force)) {
    cli::cli_abort(c(
      "{length(outstanding)} checklist step{?s} still outstanding on ",
      "#{issue_number}, so nothing was sent.",
      "i" = "First outstanding: {outstanding[1]}",
      "i" = "Pass {.code force = TRUE} to send anyway."
    ))
  }

  id <- mail_send(
    to = to,
    subject = glue::glue("RLadies+ {details$city} is set up"),
    body = chapter_confirm_body(details$city, email, meetup_url)
  )

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    glue::glue(
      "Confirmation email sent to {length(to)} organiser",
      "{if (length(to) == 1) '' else 's'} from jinx@rladies.org, ",
      "cc chapters@rladies.org.",
      if (length(outstanding) > 0) {
        glue::glue(
          "\n\nSent with {length(outstanding)} checklist step",
          "{if (length(outstanding) == 1) '' else 's'} still unticked."
        )
      } else {
        ""
      }
    )
  )

  invisible(id)
}
