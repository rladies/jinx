#' Marker opening the machine-readable block in an onboarding issue
#' @keywords internal
#' @noRd
chapter_meta_marker <- function() "<!-- jinx:chapter"

#' Render a chapter's details as a machine-readable issue block
#'
#' Onboarding issues are prose, so the details a later step needs -
#' which city, which organisers - can only be recovered by asking a
#' human to retype them. Embedding them as an HTML comment keeps the
#' issue readable while letting jinx pick the fields back up.
#'
#' Organiser **email addresses are deliberately not included**: no step
#' jinx automates needs them, and the email team already has them from
#' the request thread.
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province, or `NULL`.
#' @param organizers Character vector of organizer names.
#' @return The block as a single string.
#' @keywords internal
#' @noRd
chapter_meta_render <- function(
  city,
  country,
  region = NULL,
  organizers = character(0)
) {
  meta <- c(
    list(city = jsonlite::unbox(city), country = jsonlite::unbox(country)),
    if (!is.null(region)) list(region = jsonlite::unbox(region)),
    list(organizers = as.character(organizers))
  )
  json <- as.character(jsonlite::toJSON(
    meta,
    pretty = TRUE,
    auto_unbox = FALSE
  ))
  paste0(chapter_meta_marker(), "\n", json, "\n-->")
}

#' Recover a chapter's details from an onboarding issue body
#'
#' @param body Issue body markdown.
#' @return A named list with `city`, `country`, `region`, and
#'   `organizers`, or `NULL` when the issue carries no block.
#' @keywords internal
#' @noRd
chapter_meta_parse <- function(body) {
  body <- body %or% ""
  marker <- chapter_meta_marker()
  if (!grepl(marker, body, fixed = TRUE)) {
    return(NULL)
  }

  after <- sub(paste0("(?s)^.*?", marker), "", body, perl = TRUE)
  json <- sub("(?s)-->.*$", "", after, perl = TRUE)

  parsed <- tryCatch(
    jsonlite::fromJSON(json, simplifyVector = TRUE),
    error = function(e) {
      cli::cli_alert_warning("Onboarding issue has an unreadable jinx block")
      NULL
    }
  )
  if (is.null(parsed)) {
    return(NULL)
  }

  list(
    city = parsed$city %or% NULL,
    country = parsed$country %or% NULL,
    region = parsed$region %or% NULL,
    organizers = as.character(parsed$organizers %or% character(0))
  )
}

#' Read the machine-readable block off an onboarding issue
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return A named list of chapter details, or `NULL` when the issue
#'   carries no block.
#' @export
chapter_meta_fetch <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  issue <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number
  )
  chapter_meta_parse(issue$body)
}

#' Fill missing chapter details from an onboarding issue
#'
#' Arguments passed explicitly always win; anything left `NULL` is taken
#' from the issue's machine-readable block.
#'
#' @param supplied Named list of explicitly supplied values.
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The completed named list.
#' @keywords internal
#' @noRd
chapter_meta_complete <- function(
  supplied,
  issue_number,
  org,
  onboarding_repo
) {
  missing <- names(supplied)[vapply(supplied, is.null, logical(1))]
  if (length(missing) == 0) {
    return(supplied)
  }

  meta <- chapter_meta_fetch(issue_number, org, onboarding_repo)
  if (is.null(meta)) {
    return(supplied)
  }

  for (field in missing) {
    supplied[[field]] <- meta[[field]]
  }
  supplied
}
