YOUTUBE_API <- "https://www.googleapis.com/youtube/v3"
YOUTUBE_MAX_DESCRIPTION_CHARS <- 4000L

#' Gather chunks from a YouTube channel's uploads playlist
#'
#' Requires `YOUTUBE_API_KEY` in the environment. Pages through every
#' video in the channel's uploads playlist and emits one chunk per
#' video (title + description). Required `src` fields: `channel_id`,
#' `repo`.
#'
#' @param src Source spec list.
#' @return List of chunk records.
#' @keywords internal
gather_youtube_channel <- function(src) {
  api_key <- Sys.getenv("YOUTUBE_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    cli::cli_alert_warning("YOUTUBE_API_KEY not set - skipping youtube-channel")
    return(list())
  }
  uploads_id <- youtube_uploads_playlist(src$channel_id, api_key)
  if (is.null(uploads_id)) {
    cli::cli_alert_warning(
      "Could not resolve uploads playlist for {src$channel_id}"
    )
    return(list())
  }

  items <- youtube_playlist_items(uploads_id, api_key)
  cli::cli_alert_info("youtube-channel: {length(items)} videos in playlist")

  out <- list()
  for (item in items) {
    snippet <- item$snippet %||% list()
    video_id <- snippet$resourceId$videoId
    if (is.null(video_id)) {
      next
    }
    title <- snippet$title %||% "Untitled video"
    if (title %in% c("Private video", "Deleted video")) {
      next
    }
    description <- substr(
      snippet$description %||% "",
      1L,
      YOUTUBE_MAX_DESCRIPTION_CHARS
    )
    published <- rag_parse_date(snippet$publishedAt)
    url <- paste0("https://www.youtube.com/watch?v=", video_id)
    out[[length(out) + 1L]] <- list(
      text = format_youtube_video(title, snippet$publishedAt, description),
      heading = "YouTube",
      title = title,
      repo = src$repo %||% "rladies/youtube",
      path = paste0("video/", video_id),
      url = url,
      date = published,
      lastmod = published,
      chunk_idx = 0L
    )
  }
  out
}

format_youtube_video <- function(title, published_at, description) {
  lines <- paste0("Title: ", title)
  if (!is.null(published_at) && nzchar(published_at)) {
    lines <- c(lines, paste0("Published: ", published_at))
  }
  if (nzchar(description)) {
    lines <- c(lines, "", trimws(description))
  }
  paste(lines, collapse = "\n")
}

youtube_uploads_playlist <- function(channel_id, api_key) {
  url <- paste0(
    YOUTUBE_API,
    "/channels?part=contentDetails&id=",
    utils::URLencode(channel_id, reserved = TRUE),
    "&key=",
    api_key
  )
  body <- rag_fetch_json(url)
  body$items[[1]]$contentDetails$relatedPlaylists$uploads
}

youtube_playlist_items <- function(playlist_id, api_key) {
  out <- list()
  page_token <- ""
  repeat {
    url <- paste0(
      YOUTUBE_API,
      "/playlistItems?part=snippet&maxResults=50&playlistId=",
      utils::URLencode(playlist_id, reserved = TRUE),
      "&key=",
      api_key,
      if (nzchar(page_token)) paste0("&pageToken=", page_token) else ""
    )
    body <- rag_fetch_json(url)
    if (is.null(body)) {
      break
    }
    items <- body$items %||% list()
    out <- c(out, items)
    if (is.null(body$nextPageToken) || !nzchar(body$nextPageToken)) {
      break
    }
    page_token <- body$nextPageToken
  }
  out
}
