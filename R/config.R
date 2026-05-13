#' Load teams configuration
#'
#' @return Named list with organization, global_team_id, teams, and
#'   default_assignees.
#' @export
load_teams_config <- function() {
  path <- system.file("config", "teams.yml", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("teams.yml not found in jinx package")
  }
  yaml::read_yaml(path)
}

#' Load PR review rules
#'
#' @return Named list with defaults, rules, and naming conventions.
#' @export
load_review_rules <- function() {
  path <- system.file("config", "review-rules.yml", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("review-rules.yml not found in jinx package")
  }
  yaml::read_yaml(path)
}

#' Load file-path to label mappings
#'
#' @return Named list with label mappings.
#' @export
load_labels_config <- function() {
  path <- system.file("config", "labels.yml", package = "jinx")
  if (!nzchar(path)) {
    cli::cli_abort("labels.yml not found in jinx package")
  }
  yaml::read_yaml(path)
}

#' Look up a team by slug
#'
#' @param slug Team slug (e.g. "website", "blog").
#' @param config Teams config as returned by [load_teams_config()]. Loaded
#'   automatically if `NULL`.
#' @return Named list with team definition, or `NULL` if not found.
#' @keywords internal
#' @noRd
team_get_by_slug <- function(slug, config = NULL) {
  config <- config %||% load_teams_config()
  config$teams[[slug]]
}

#' List all valid team slugs
#'
#' @param config Teams config as returned by [load_teams_config()]. Loaded
#'   automatically if `NULL`.
#' @return Character vector of team slugs.
#' @keywords internal
#' @noRd
team_list_slugs <- function(config = NULL) {
  config <- config %||% load_teams_config()
  names(config$teams)
}
