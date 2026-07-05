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

#' Mark Airtable records as processed.
#'
#' PATCHes each record's boolean `field` to `TRUE`, in batches of 10 (the
#' Airtable write limit). Called after a sync PR merges to flag the submissions
#' whose entries are now live in the directory, so subsequent syncs skip them.
#' @keywords internal
airtable_mark_processed <- function(
  base_id,
  table,
  record_ids,
  api_key,
  field = directory_synced_field()
) {
  record_ids <- unique(record_ids[!is.na(record_ids) & nzchar(record_ids)])
  if (length(record_ids) == 0) {
    return(invisible(character(0)))
  }

  for (payload in airtable_mark_batches(record_ids, field)) {
    httr2::request(
      glue::glue("https://api.airtable.com/v0/{base_id}/{table}")
    ) |>
      httr2::req_method("PATCH") |>
      httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
      httr2::req_body_json(payload) |>
      httr2::req_retry(max_tries = 3, backoff = function(i) i) |>
      httr2::req_perform()
  }

  invisible(record_ids)
}

#' Split record ids into Airtable PATCH payloads of at most 10 records.
#'
#' Each payload sets `field` to `TRUE` on its records, ready for
#' `httr2::req_body_json()`.
#' @keywords internal
airtable_mark_batches <- function(record_ids, field) {
  batches <- split(record_ids, ceiling(seq_along(record_ids) / 10))
  lapply(unname(batches), function(batch) {
    list(
      records = lapply(batch, function(id) {
        fields <- list(TRUE)
        names(fields) <- field
        list(id = id, fields = fields)
      })
    )
  })
}

#' Delete Airtable records by id, one request each.
#'
#' Used by the GDPR purge. A per-record `DELETE` keeps it simple and robust for
#' the small counts a purge touches; the caller re-derives the id list from a
#' fresh listing, so a re-run never re-deletes an already-gone record.
#' @keywords internal
airtable_delete_records <- function(base_id, table, record_ids, api_key) {
  record_ids <- unique(record_ids[!is.na(record_ids) & nzchar(record_ids)])
  for (id in record_ids) {
    httr2::request(
      glue::glue("https://api.airtable.com/v0/{base_id}/{table}/{id}")
    ) |>
      httr2::req_method("DELETE") |>
      httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
      httr2::req_retry(max_tries = 3, backoff = function(i) i) |>
      httr2::req_perform()
  }
  invisible(record_ids)
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
