#' Render a template with placeholder replacement
#'
#' Replaces `<KEY>` placeholders in the template with the corresponding
#' values from `variables`.
#'
#' @param template_path Path to the markdown template file.
#' @param variables Named list of placeholder values. Names should match
#'   the placeholder keys (without angle brackets).
#' @return Rendered template as a single character string.
#' @keywords internal
#' @noRd
render_template <- function(template_path, variables) {
  content <- paste(readLines(template_path, warn = FALSE), collapse = "\n")
  for (key in names(variables)) {
    content <- gsub(
      paste0("<", key, ">"),
      variables[[key]],
      content,
      fixed = TRUE
    )
  }
  content
}

#' Combine base template with team-specific extras
#'
#' Team templates may contain HTML comments `<!-- Extra for us ... -->`
#' that get injected before the second `###` header in the base template.
#'
#' @param base_content Rendered base template string.
#' @param team_content Rendered team template string.
#' @return Combined template as a single character string.
#' @keywords internal
#' @noRd
combine_templates <- function(base_content, team_content) {
  extras <- extract_extras(team_content)
  if (is.null(extras)) {
    return(paste(base_content, team_content, sep = "\n\n"))
  }
  inject_before_second_header(base_content, extras)
}

extract_extras <- function(content) {
  pattern <- "<!--\\s*Extra for us\\s*\n((?:.|\\n)*?)-->"
  match <- regmatches(content, regexec(pattern, content, perl = TRUE))[[1]]
  if (length(match) < 2) {
    return(NULL)
  }
  trimws(match[2])
}

inject_before_second_header <- function(base, extras) {
  lines <- strsplit(base, "\n")[[1]]
  header_positions <- grep("^###\\s", lines)

  if (length(header_positions) < 2) {
    return(paste(base, extras, sep = "\n\n"))
  }

  insert_at <- header_positions[2]
  before <- lines[seq_len(insert_at - 1)]
  after <- lines[insert_at:length(lines)]

  paste(c(before, "", extras, "", after), collapse = "\n")
}

#' Build a global team onboarding issue body
#'
#' @param team_slug Team slug (e.g. "website").
#' @param username GitHub username.
#' @param name Full name.
#' @return Rendered issue body as a single character string.
#' @keywords internal
#' @noRd
gt_build_onboarding_body <- function(team_slug, username, name) {
  base_path <- system.file(
    "templates",
    "global-team-onboarding.md",
    package = "jinx"
  )
  team_path <- system.file(
    "templates",
    "teams",
    paste0(team_slug, ".md"),
    package = "jinx"
  )

  variables <- list(
    GH_USER = username,
    NAME = name,
    TEAM = team_slug
  )

  base <- render_template(base_path, variables)

  if (nzchar(team_path)) {
    team <- render_template(team_path, variables)
    combine_templates(base, team)
  } else {
    base
  }
}

#' Build a global team offboarding issue body
#'
#' @param team_slug Team slug.
#' @param username GitHub username.
#' @param name Full name.
#' @return Rendered issue body as a single character string.
#' @keywords internal
#' @noRd
gt_build_offboarding_body <- function(team_slug, username, name) {
  base_path <- system.file(
    "templates",
    "global-team-offboarding.md",
    package = "jinx"
  )

  variables <- list(
    GH_USER = username,
    NAME = name,
    TEAM = team_slug
  )

  render_template(base_path, variables)
}
