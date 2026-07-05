#' Gather chunks from a meetup events JSON feed
#'
#' Reads an array of meetup events, drops cancelled events and past
#' events older than `past_window_seconds`, and emits one chunk per
#' remaining event plus a single cross-chapter digest of every upcoming
#' event (see [events_digest_chunk()]). Required `src` fields: `url`,
#' `repo`.
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

  digest <- events_digest_chunk(events, src)
  if (!is.null(digest)) {
    chunks <- c(chunks, list(digest))
  }

  cli::cli_alert_info("events-json: {length(chunks)} chunks")
  chunks
}

#' Build one cross-chapter digest chunk of all upcoming events
#'
#' Vector search over per-event chunks cannot answer "when is the next
#' event, regardless of chapter" — upcoming-ness is a structured filter,
#' not a semantic property, and only a handful of events are upcoming at
#' any time. This emits a single `events-digest` chunk listing every
#' upcoming event across all chapters, soonest first, so retrieval has a
#' complete global view to answer from. Returns `NULL` when nothing is
#' upcoming.
#'
#' @param ev_list Full list of raw event records.
#' @param src Source spec list.
#' @param max_events Cap the number of events rendered into the digest.
#' @param landing_url Canonical URL for the full events listing.
#' @return A chunk record, or `NULL`.
#' @keywords internal
events_digest_chunk <- function(
  ev_list,
  src,
  max_events = src$digest_max_events %or% 30L,
  landing_url = src$digest_url %or% "https://rladies.org/events/"
) {
  upcoming <- Filter(function(ev) identical(ev$status, "active"), ev_list)
  if (length(upcoming) == 0L) {
    return(NULL)
  }

  ts <- vapply(
    upcoming,
    function(ev) rag_parse_date(ev$datetime_utc %or% ev$datetime),
    integer(1)
  )
  ord <- order(ts)
  upcoming <- upcoming[ord]
  ts <- ts[ord]

  shown <- upcoming[seq_len(min(max_events, length(upcoming)))]
  lines <- vapply(shown, format_event_digest_line, character(1))
  header <- paste0(
    "Upcoming RLadies+ events across all chapters, soonest first ",
    "(",
    length(upcoming),
    " upcoming in total). Use this to answer ",
    "questions about the next or upcoming events regardless of chapter; ",
    "quote the soonest entry and its When date."
  )
  overflow <- if (length(upcoming) > max_events) {
    paste0(
      "\n\n...and ",
      length(upcoming) - max_events,
      " more upcoming events. See <",
      landing_url,
      "|all RLadies+ events> for the full list."
    )
  } else {
    ""
  }
  text <- paste0(header, "\n\n", paste(lines, collapse = "\n"), overflow)

  soonest <- ts[ts > 0L]
  date <- if (length(soonest) > 0L) soonest[[1L]] else 0L

  list(
    text = text,
    heading = "All chapters",
    title = "Upcoming RLadies+ events",
    repo = src$repo,
    path = "digest/upcoming-events",
    url = landing_url,
    date = date,
    lastmod = date,
    chunk_idx = 0L,
    source_type = "events-digest"
  )
}

#' Render one upcoming event as a Slack-linked digest bullet
#' @keywords internal
format_event_digest_line <- function(ev) {
  when <- ev$datetime %or% ev$datetime_utc %or% "date TBD"
  chapter <- ev$group_name %or% "RLadies+ chapter"
  title <- ev$title %or% "Untitled event"
  label <- paste0(chapter, ": ", title)
  linked <- if (!is_blank(ev$link)) {
    paste0("<", ev$link, "|", label, ">")
  } else {
    label
  }
  venue <- format_event_venue(ev)
  where <- if (nzchar(venue)) paste0(" (", venue, ")") else ""
  paste0("- ", when, " - ", linked, where)
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
