#' Fetch a canonical communications template from the guide
#'
#' Organisational communications - what RLadies+ says to organisers and
#' chapters - are written and edited in the guide, under
#' `static/templates/`, and served as markdown from
#' `https://guide.rladies.org/templates/<name>.md`. jinx fetches them
#' instead of shipping copies, so a volunteer can fix the wording
#' without waiting for a package release, and the text an organiser
#' reads in the guide is the text jinx sends.
#'
#' A failed fetch is an error. There is deliberately no vendored
#' fallback, because a second copy is the drift this replaces.
#'
#' Use [guide_email_template()] for a template that is sent as email and
#' so carries its own subject line.
#'
#' @param name Template name without extension, as it is filed in the
#'   guide (for example `"meetup-group-description"`).
#' @param variables Named list of `<<KEY>>` placeholder values. Keys are
#'   given without the angle brackets. Placeholders the guide leaves for
#'   a human to fill are passed through untouched.
#' @param base_url Guide base URL, for testing against a local build.
#' @return The template text, as a single string.
#' @examples
#' \dontrun{
#' guide_template("meetup-group-description")
#'
#' guide_template(
#'   "chapter-onboarding-welcome",
#'   list(FIRST_NAME = "Ada", CITY = "Oslo")
#' )
#' }
#' @export
guide_template <- function(
  name,
  variables = list(),
  base_url = guide_base_url()
) {
  render_placeholders(
    trimws(guide_template_fetch(name, base_url)),
    variables
  )
}

#' Fetch a canonical email template from the guide
#'
#' The guide writes the templates that are sent as email with their
#' subject on a leading `SUBJECT:` line, followed by
#' `BODY OF THE MESSAGE:`. This splits the two apart so that callers send
#' the guide's subject rather than inventing one, and errors if the
#' template carries no subject at all.
#'
#' @inheritParams guide_template
#' @return A list with `name`, `subject` and `body`.
#' @examples
#' \dontrun{
#' notice <- guide_email_template("chapter-inactive-first-notice")
#' notice$subject
#' }
#' @seealso [guide_template()] for a template with no subject line.
#' @export
guide_email_template <- function(
  name,
  variables = list(),
  base_url = guide_base_url()
) {
  parts <- guide_template_split(guide_template_fetch(name, base_url))

  if (!nzchar(parts$subject)) {
    cli::cli_abort(c(
      "The guide's {.val {name}} template carries no subject line.",
      "i" = "An email template needs a leading {.code SUBJECT:} line.",
      "i" = "Use {.fn guide_template} for a template without one."
    ))
  }

  list(
    name = name,
    subject = render_placeholders(parts$subject, variables),
    body = render_placeholders(parts$body, variables)
  )
}

guide_base_url <- function() {
  getOption("jinx.guide_url", "https://guide.rladies.org")
}

guide_template_fetch <- function(name, base_url = guide_base_url()) {
  resp <- tryCatch(
    httr2::request(base_url) |>
      httr2::req_url_path_append("templates", paste0(name, ".md")) |>
      httr2::req_timeout(15) |>
      httr2::req_perform(),
    error = function(e) {
      cli::cli_abort(c(
        "Could not fetch the {.val {name}} template from the guide.",
        "x" = e$message,
        "i" = "The guide holds the only copy; jinx keeps no fallback."
      ))
    }
  )

  content_type <- httr2::resp_content_type(resp)
  if (!content_type %in% c("text/markdown", "text/plain")) {
    cli::cli_abort(c(
      "The guide served {.val {content_type}} for the {.val {name}} template.",
      "i" = "Expected markdown. An HTML page here is an error page, not text
             to send to a chapter."
    ))
  }

  text <- httr2::resp_body_string(resp)
  if (!nzchar(trimws(text))) {
    cli::cli_abort("The guide served an empty {.val {name}} template.")
  }
  text
}

guide_template_split <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  subject_at <- grep("^SUBJECT:", lines)

  if (length(subject_at) == 0) {
    return(list(subject = "", body = trimws(text)))
  }

  body_at <- grep("^BODY OF THE MESSAGE:", lines)
  starts_at <- if (length(body_at) == 0) {
    subject_at[1] + 1L
  } else {
    body_at[1] + 1L
  }

  body <- if (starts_at > length(lines)) {
    ""
  } else {
    paste(lines[seq(starts_at, length(lines))], collapse = "\n")
  }

  list(
    subject = trimws(sub("^SUBJECT:", "", lines[subject_at[1]])),
    body = trimws(body)
  )
}
