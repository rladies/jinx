#' Sync global team data from Airtable
#'
#' Fetches global team member data from Airtable and updates the
#' website repo data files.
#'
#' @param base_id Airtable base ID for the global team.
#' @param api_key Airtable API key.
#' @param org GitHub organization.
#' @param website_repo Website repository name.
#' @return PR URL if changes found, `NULL` otherwise (invisibly).
#' @export
gt_sync_airtable <- function(
  base_id = "appZjaV7eM0Y9FsHZ",
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  website_repo = "rladies.github.io"
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }

  cli::cli_h2("Syncing global team from Airtable")

  members <- airtable_list_records(base_id, "Members", api_key)
  teams <- airtable_list_records(base_id, "Teams", api_key)
  alumni <- airtable_list_records(base_id, "Alumni", api_key)

  team_map <- stats::setNames(
    vapply(teams, function(t) t$fields$Team %||% "", character(1)),
    vapply(teams, function(t) t$id, character(1))
  )

  current <- lapply(members, function(m) {
    roles <- vapply(
      m$fields[["Team membership"]] %||% list(),
      function(tid) team_map[[tid]] %||% "Unknown",
      character(1)
    )
    list(
      name = m$fields$Name %||% "",
      role = as.list(roles),
      start = m$fields[["Start date"]],
      img = airtable_extract_photo(m$fields$photo)
    )
  })

  alumni_list <- lapply(alumni, function(a) {
    list(
      name = a$fields$Name %||% "",
      role = as.list(strsplit(a$fields$History %||% "", ",\\s*")[[1]]),
      start = a$fields[["Start Date"]],
      end = a$fields[["End Date"]],
      img = airtable_extract_photo(a$fields$photo),
      airtable_id = a$id
    )
  })

  cli::cli_alert_info(
    "Found {length(current)} current members, {length(alumni_list)} alumni"
  )

  list(current = current, alumni = alumni_list)
}

#' List all records from an Airtable table, following pagination.
#' @keywords internal
airtable_list_records <- function(base_id, table, api_key) {
  all_records <- list()
  offset <- NULL

  repeat {
    query <- list(pageSize = 100)
    if (!is.null(offset)) {
      query$offset <- offset
    }

    resp <- httr2::request(
      glue::glue("https://api.airtable.com/v0/{base_id}/{table}")
    ) |>
      httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
      httr2::req_url_query(!!!query) |>
      httr2::req_retry(max_tries = 3, backoff = function(i) i) |>
      httr2::req_perform() |>
      httr2::resp_body_json()

    all_records <- c(all_records, resp$records)
    offset <- resp$offset
    if (is.null(offset)) break
  }

  all_records
}

#' Extract the first photo URL from an Airtable attachment field.
#' @keywords internal
airtable_extract_photo <- function(photo_field) {
  if (is.null(photo_field) || length(photo_field) == 0) {
    return(NULL)
  }
  photo <- photo_field[[1]]
  if (!is.null(photo$url)) photo$url else NULL
}
