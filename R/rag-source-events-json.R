EVENTS_PAST_WINDOW_SECONDS <- 365L * 24L * 60L * 60L
EVENTS_MIN_CHARS <- 80L

#' Gather chunks from a meetup events JSON feed
#'
#' Reads an array of meetup events, drops cancelled events and past
#' events older than one year, and emits one chunk per remaining event.
#' Required `src` fields: `url`, `repo`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_events_json <- function(src) {
  events <- rag_fetch_json(httr2::request(src$url))
  if (!is.list(events) || length(events) == 0L) {
    cli::cli_alert_warning("events-json: no array at {src$url}")
    return(list())
  }

  cutoff <- as.integer(Sys.time()) - EVENTS_PAST_WINDOW_SECONDS
  chunks <- lapply(events, event_to_chunk, src = src, cutoff = cutoff)
  chunks <- Filter(Negate(is.null), chunks)
  cli::cli_alert_info("events-json: {length(chunks)} chunks")
  chunks
}

event_to_chunk <- function(ev, src, cutoff) {
  if (identical(ev$status, "cancelled")) {
    return(NULL)
  }
  ts <- rag_parse_date(ev$datetime_utc %||% ev$datetime)
  if (identical(ev$status, "past") && ts > 0L && ts < cutoff) {
    return(NULL)
  }

  text <- format_event(ev)
  if (nchar(text) < EVENTS_MIN_CHARS) {
    return(NULL)
  }

  id <- as.character(
    ev$id %||% ev$link %||% paste0(ev$group_urlname, "-", ts)
  )
  list(
    text = text,
    heading = ev$group_name %||% "",
    title = ev$title %||% "Untitled event",
    repo = src$repo,
    path = paste0("event/", id),
    url = ev$link,
    date = ts,
    lastmod = ts,
    chunk_idx = 0L
  )
}

format_event <- function(ev) {
  status_label <- if (identical(ev$status, "active")) "upcoming" else "past"
  fields <- c(
    Title = ev$title,
    Chapter = ev$group_name,
    When = ev$datetime %||% ev$datetime_utc,
    Status = if (!is.null(ev$status)) status_label,
    Where = nz(format_event_venue(ev)),
    Attendance = if (!is.null(ev$going)) as.character(ev$going)
  )
  lines <- paste0(names(fields), ": ", fields)
  if (!is.null(ev$description) && nzchar(ev$description)) {
    lines <- c(lines, "", trimws(strip_html(ev$description)))
  }
  paste(lines, collapse = "\n")
}

format_event_venue <- function(ev) {
  parts <- c(ev$venue_name, ev$venue_address, ev$venue_city, ev$venue_country)
  parts <- parts[lengths(parts) > 0L & nzchar(parts)]
  if (length(parts) == 0L) {
    return(ev$location %||% "")
  }
  paste(parts, collapse = ", ")
}

strip_html <- function(s) {
  trimws(gsub("\\s+", " ", gsub("<[^>]+>", " ", s)))
}

nz <- function(x) if (length(x) && nzchar(x)) x else NULL
