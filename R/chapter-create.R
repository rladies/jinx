#' Create a new chapter JSON file
#'
#' Generates a chapter JSON entry for the website.
#'
#' @param city City name.
#' @param country Country name.
#' @param organizers Character vector of organizer names.
#' @param social_media Named list of social media links (e.g.
#'   `list(meetup = "...", email = "city@rladies.org")`).
#' @param status Chapter status. Defaults to `"prospective"`.
#' @param output_dir Directory to write the JSON file.
#' @return File path of the created JSON (invisibly).
#' @export
chapter_create <- function(
  city,
  country,
  organizers,
  social_media = list(),
  status = "prospective",
  output_dir = "."
) {
  slug <- tolower(gsub(
    "[^a-z0-9]+",
    "-",
    paste(country, city),
    ignore.case = TRUE
  ))
  slug <- gsub("^-|-$", "", slug)

  chapter <- list(
    urlname = paste0("rladies-", tolower(gsub(" ", "-", city, fixed = TRUE))),
    status = status,
    country = country,
    city = city,
    social_media = social_media,
    organizers = list(
      current = as.list(organizers),
      former = list()
    )
  )

  filename <- paste0(slug, ".json")
  filepath <- file.path(output_dir, filename)

  jsonlite::write_json(
    chapter,
    filepath,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  cli::cli_alert_success("Created chapter file: {.path {filename}}")
  invisible(filepath)
}
