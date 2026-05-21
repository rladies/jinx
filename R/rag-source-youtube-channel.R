#' Build a base YouTube Data API v3 request
#'
#' Returns an [httr2::request] with the API base URL and `key` query
#' parameter attached. Callers append path + extra query params:
#'
#' ```r
#' youtube_request(key) |>
#'   httr2::req_url_path_append("channels") |>
#'   httr2::req_url_query(part = "contentDetails", id = channel_id)
#' ```
#'
#' @param api_key YouTube Data API key.
#' @param user_agent User-Agent header to attach.
#' @param base_url YouTube Data API base URL.
#' @return [httr2::request] object.
#' @keywords internal
youtube_request <- function(
  api_key,
  user_agent = rag_user_agent(),
  base_url = "https://www.googleapis.com/youtube/v3"
) {
  httr2::request(base_url) |>
    httr2::req_url_query(key = api_key) |>
    httr2::req_user_agent(user_agent)
}

#' Gather chunks from a YouTube channel's uploads playlist
#'
#' Requires `YOUTUBE_API_KEY` in the environment. Pages through every
#' video in the channel's uploads playlist and emits one chunk per
#' video (title + description). Required `src` fields: `channel_id`,
#' `repo`.
#'
#' @param src Source spec list.
#' @param max_description_chars Cap on bytes of description kept per video.
#' @return List of chunk records.
#' @keywords internal
gather_youtube_channel <- function(
  src,
  max_description_chars = src$max_description_chars %||% 4000L
) {
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

  chunks <- lapply(
    items,
    video_to_chunk,
    src = src,
    max_description_chars = max_description_chars
  )
  Filter(Negate(is.null), chunks)
}

video_to_chunk <- function(item, src, max_description_chars) {
  snippet <- item$snippet %||% list()
  video_id <- snippet$resourceId$videoId
  if (is.null(video_id)) {
    return(NULL)
  }
  title <- snippet$title %||% "Untitled video"
  if (title %in% c("Private video", "Deleted video")) {
    return(NULL)
  }

  description <- substr(
    snippet$description %||% "",
    1L,
    max_description_chars
  )
  published <- rag_parse_date(snippet$publishedAt)
  list(
    text = format_youtube_video(title, snippet$publishedAt, description),
    heading = "YouTube",
    title = title,
    repo = src$repo %||% "rladies/youtube",
    path = paste0("video/", video_id),
    url = httr2::request("https://www.youtube.com/watch") |>
      httr2::req_url_query(v = video_id) |>
      _$url,
    date = published,
    lastmod = published,
    chunk_idx = 0L
  )
}

format_youtube_video <- function(title, published_at, description) {
  fields <- c(
    Title = title,
    Published = if (length(published_at) && nzchar(published_at)) published_at
  )
  lines <- paste0(names(fields), ": ", fields)
  if (nzchar(description)) {
    lines <- c(lines, "", trimws(description))
  }
  paste(lines, collapse = "\n")
}

youtube_uploads_playlist <- function(channel_id, api_key) {
  body <- youtube_request(api_key) |>
    httr2::req_url_path_append("channels") |>
    httr2::req_url_query(part = "contentDetails", id = channel_id) |>
    rag_fetch_json()
  body$items[[1]]$contentDetails$relatedPlaylists$uploads
}

youtube_playlist_items <- function(playlist_id, api_key) {
  base <- youtube_request(api_key) |>
    httr2::req_url_path_append("playlistItems") |>
    httr2::req_url_query(
      part = "snippet",
      maxResults = 50L,
      playlistId = playlist_id
    )
  out <- list()
  page_token <- ""
  repeat {
    req <- if (nzchar(page_token)) {
      httr2::req_url_query(base, pageToken = page_token)
    } else {
      base
    }
    body <- rag_fetch_json(req)
    if (is.null(body)) {
      break
    }
    out <- c(out, body$items %||% list())
    if (is.null(body$nextPageToken) || !nzchar(body$nextPageToken)) {
      break
    }
    page_token <- body$nextPageToken
  }
  out
}
