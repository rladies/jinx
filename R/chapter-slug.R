#' Slugify chapter name parts the way the website filenames do
#'
#' Transliterates to ASCII, lowercases, collapses every run of
#' non-alphanumeric characters into a single hyphen, and trims hyphens
#' from both ends. `Cordoba` and `Córdoba` both slugify to `cordoba`,
#' matching the filenames already in `data/chapters`.
#'
#' @param ... Character parts to join before slugifying. `NULL`, `NA`,
#'   and empty parts are dropped.
#' @return A single slug string.
#' @keywords internal
#' @noRd
chapter_slug <- function(...) {
  parts <- unlist(list(...), use.names = FALSE)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts) == 0) {
    return("")
  }
  ascii <- stringi::stri_trans_general(
    paste(parts, collapse = "-"),
    "Any-Latin; Latin-ASCII"
  )
  slug <- gsub("[^a-z0-9]+", "-", tolower(ascii), perl = TRUE)
  gsub("^-+|-+$", "", slug, perl = TRUE)
}

#' Build the website filename for a chapter
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province, or `NULL`.
#' @return Filename including the `.json` extension.
#' @keywords internal
#' @noRd
chapter_filename <- function(city, country, region = NULL) {
  paste0(chapter_slug(country, region, city), ".json")
}
