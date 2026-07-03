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

airtable_to_directory_entry <- function(record) {
  fields <- record$fields
  name <- fields$Name
  if (is.null(name) || !nzchar(name)) {
    return(NULL)
  }

  name_slug <- tolower(gsub("[^a-z0-9]+", "-", tolower(name), perl = TRUE))
  name_slug <- sub("^-|-$", "", name_slug)
  id_suffix <- substr(
    openssl::sha1(record$id %||% name),
    1,
    6
  )
  slug <- paste0(name_slug, "-", id_suffix)

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
