#' Sync directory entries from Airtable
#'
#' Fetches directory entries from Airtable and updates the directory repo.
#' Creates a PR with new/updated entries for review.
#'
#' @param base_id Airtable base ID.
#' @param api_key Airtable API key. Defaults to `AIRTABLE_API_KEY` env var.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param directory_repo Directory repository name.
#' @return PR URL if changes found, `NULL` otherwise (invisibly).
#' @export
directory_sync_airtable <- function(
  base_id = "appM6GuE0Jl1UI9qx",
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  directory_repo = "directory"
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("AIRTABLE_API_KEY environment variable is not set")
  }

  cli::cli_h2("Syncing directory from Airtable")
  records <- airtable_list_records(base_id, "Directory", api_key)

  if (length(records) == 0) {
    cli::cli_alert_info("No records to sync")
    return(invisible(NULL))
  }

  entries <- lapply(records, airtable_to_directory_entry)
  entries <- Filter(Negate(is.null), entries)
  cli::cli_alert_info("Processing {length(entries)} entries")

  changed <- write_directory_entries(entries, org, directory_repo)

  if (length(changed) == 0) {
    cli::cli_alert_success("No changes detected")
    return(invisible(NULL))
  }

  pr_url <- directory_create_pr(changed, org, directory_repo)
  if (is.null(pr_url)) {
    cli::cli_alert_success("No PR opened; nothing to push")
    return(invisible(NULL))
  }
  cli::cli_alert_success("PR ready with {length(changed)} changes: {pr_url}")
  invisible(pr_url)
}

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
      httr2::req_perform() |>
      httr2::resp_body_json()

    all_records <- c(all_records, resp$records)
    offset <- resp$offset
    if (is.null(offset)) break
  }

  all_records
}

airtable_to_directory_entry <- function(record) {
  fields <- record$fields
  name <- fields$Name
  if (is.null(name) || !nzchar(name)) {
    return(NULL)
  }

  slug <- tolower(gsub("[^a-z0-9]+", "-", tolower(name), perl = TRUE))
  slug <- sub("^-|-$", "", slug)

  entry <- list(name = name)

  social_fields <- c(
    "twitter",
    "github",
    "linkedin",
    "mastodon",
    "bluesky",
    "website",
    "orcid"
  )
  for (field in social_fields) {
    val <- fields[[field]]
    if (!is.null(val) && nzchar(val)) {
      entry[[field]] <- val
    }
  }

  list(slug = slug, data = entry, airtable_id = record$id)
}

airtable_extract_photo <- function(photo_field) {
  if (is.null(photo_field) || length(photo_field) == 0) {
    return(NULL)
  }
  photo <- photo_field[[1]]
  if (!is.null(photo$url)) photo$url else NULL
}

write_directory_entries <- function(entries, org, repo, ref = "main") {
  changed <- list()

  for (entry in entries) {
    json <- jsonlite::toJSON(entry$data, pretty = TRUE, auto_unbox = TRUE)
    filename <- paste0(entry$slug, ".json")
    path <- glue::glue("contact/{filename}")

    existing <- tryCatch(
      gh::gh(
        "GET /repos/{owner}/{repo}/contents/{path}",
        owner = org,
        repo = repo,
        path = path,
        ref = ref
      ),
      error = function(e) NULL
    )

    existing_content <- if (!is.null(existing)) {
      rawToChar(jsonlite::base64_dec(existing$content))
    }

    if (
      is.null(existing_content) ||
        trimws(existing_content) != trimws(as.character(json))
    ) {
      changed[[length(changed) + 1]] <- list(
        filename = filename,
        path = path,
        content = as.character(json),
        sha = if (!is.null(existing)) existing$sha else NULL
      )
    }
  }

  changed
}

directory_create_pr <- function(changed, org, repo, base = "main") {
  if (length(changed) == 0) {
    return(invisible(NULL))
  }

  branch <- paste0("jinx/airtable-sync-", format(Sys.Date(), "%Y%m%d"))
  gh_branch_upsert(org, repo, branch, base = base)

  for (file in changed) {
    params <- list(
      owner = org,
      repo = repo,
      path = file$path,
      message = glue::glue("Sync {file$filename} from Airtable"),
      content = jsonlite::base64_enc(charToRaw(file$content)),
      branch = branch
    )
    if (!is.null(file$sha)) {
      params$sha <- file$sha
    }
    do.call(gh::gh, c("PUT /repos/{owner}/{repo}/contents/{path}", params))
  }

  body <- paste0(
    "Automated sync of directory entries from Airtable.\n\n",
    "- **Entries changed**: ",
    length(changed),
    "\n\n",
    "_Created by jinx_"
  )

  gh_open_or_update_pr(
    org,
    repo,
    branch,
    base = base,
    title = glue::glue("Airtable directory sync - {Sys.Date()}"),
    body = body
  )
}
