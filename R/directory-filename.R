#' Validate a directory entry filename
#'
#' Checks that filenames follow conventions: lowercase, no hashes,
#' ASCII-only, `.json` extension.
#'
#' @param filename Filename (not full path) to validate.
#' @return A named list with `valid` (logical) and `issues` (character
#'   vector of problems found).
#' @export
validate_entry_filename <- function(filename) {
  issues <- character()

  if (!grepl("\\.json$", filename)) {
    issues <- c(issues, "Must have .json extension")
  }

  name <- sub("\\.json$", "", filename)

  if (name != tolower(name)) {
    issues <- c(issues, "Must be lowercase")
  }

  if (grepl("#", name)) {
    issues <- c(issues, "Must not contain hash (#)")
  }

  if (grepl("[^a-z0-9._-]", name)) {
    issues <- c(
      issues,
      "Must contain only ASCII letters, numbers, dots, hyphens, underscores"
    )
  }

  if (grepl("^-|-$", name)) {
    issues <- c(issues, "Must not start or end with hyphen")
  }

  list(valid = length(issues) == 0, issues = issues)
}
