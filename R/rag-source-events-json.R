#' Gather chunks from a meetup events JSON feed
#'
#' Reads an array of meetup events, drops cancelled events and past
#' events older than `past_window_seconds`, and emits one chunk per
#' remaining event. Required `src` fields: `url`, `repo`.
#'
#' @param src Source spec list.
#' @param past_window_seconds Drop `past` events older than this many
#'   seconds before now.
#' @param min_chars Drop chunks shorter than this many characters.
#' @return List of chunk records.
#' @keywords internal
gather_events_json <- function(
  src,
  past_window_seconds = src$past_window_seconds %or% (365L * 24L * 60L * 60L),
  min_chars = src$min_chars %or% 80L
) {
  events <- rag_fetch_json(rag_request(src$url))
  if (!is.list(events) || length(events) == 0L) {
    cli::cli_alert_warning("events-json: no array at {src$url}")
    return(list())
  }

  cutoff <- as.numeric(Sys.time()) - past_window_seconds
  chunks <- lapply(
    events,
    event_to_chunk,
    src = src,
    cutoff = cutoff,
    min_chars = min_chars
  )
  chunks <- Filter(Negate(is.null), chunks)
  cli::cli_alert_info("events-json: {length(chunks)} chunks")
  chunks
}

#' Convert a meetup event record into a chunk record
#' @keywords internal
event_to_chunk <- function(ev, src, cutoff, min_chars) {
  if (identical(ev$status, "cancelled")) {
    return(NULL)
  }
  ts <- rag_parse_date(ev$datetime_utc %or% ev$datetime)
  if (identical(ev$status, "past") && ts > 0L && ts < cutoff) {
    return(NULL)
  }

  text <- format_event(ev)
  if (nchar(text) < min_chars) {
    return(NULL)
  }

  id <- as.character(
    ev$id %or% ev$link %or% paste0(ev$group_urlname, "-", ts)
  )
  list(
    text = text,
    heading = ev$group_name %or% "",
    title = ev$title %or% "Untitled event",
    repo = src$repo,
    path = paste0("event/", id),
    url = ev$link,
    date = ts,
    lastmod = ts,
    chunk_idx = 0L
  )
}

#' Format a meetup event as a labelled text block
#' @keywords internal
format_event <- function(ev) {
  status_label <- if (identical(ev$status, "active")) "upcoming" else "past"
  venue <- format_event_venue(ev)
  fields <- c(
    Title = ev$title,
    Chapter = ev$group_name,
    When = ev$datetime %or% ev$datetime_utc,
    Status = if (!is.null(ev$status)) status_label,
    Where = if (nzchar(venue)) venue,
    Attendance = if (!is.null(ev$going)) as.character(ev$going)
  )
  lines <- paste0(names(fields), ": ", fields)
  if (!is_blank(ev$description)) {
    lines <- c(lines, "", trimws(strip_html(ev$description)))
  }
  paste(lines, collapse = "\n")
}

#' Build a comma-separated venue string from event fields
#' @keywords internal
format_event_venue <- function(ev) {
  parts <- c(ev$venue_name, ev$venue_address, ev$venue_city, ev$venue_country)
  parts <- parts[lengths(parts) > 0L & nzchar(parts)]
  if (length(parts) == 0L) {
    return(ev$location %or% "")
  }
  paste(parts, collapse = ", ")
}

#' Strip HTML tags and collapse whitespace
#' @keywords internal
strip_html <- function(s) {
  trimws(gsub("\\s+", " ", gsub("<[^>]+>", " ", s)))
}
