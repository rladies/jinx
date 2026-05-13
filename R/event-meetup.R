#' List events from the Meetup GraphQL API
#'
#' @param group_urlname Meetup group URL name (e.g. "rladies-berlin").
#' @param months Number of months of history to fetch.
#' @param api_key Meetup Pro API key. Defaults to `MEETUP_API_KEY` env var.
#' @return Data frame with columns: title, date, url, rsvp_count, source,
#'   chapter.
#' @noRd
event_meetup_list <- function(
  group_urlname,
  months = 3,
  api_key = Sys.getenv("MEETUP_API_KEY")
) {
  if (!nzchar(api_key)) {
    cli::cli_abort("MEETUP_API_KEY environment variable is not set")
  }

  since <- format(Sys.Date() - lubridate::dmonths(months), "%Y-%m-%dT00:00:00")

  query <- sprintf(
    '{
    groupByUrlname(urlname: "%s") {
      pastEvents(input: { first: 50 }) {
        edges {
          node {
            title
            dateTime
            eventUrl
            going
          }
        }
      }
    }
  }',
    group_urlname
  )

  resp <- httr2::request("https://api.meetup.com/gql") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key)) |>
    httr2::req_body_json(list(query = query)) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform()

  result <- httr2::resp_body_json(resp)
  edges <- result$data$groupByUrlname$pastEvents$edges %||% list()

  events <- lapply(edges, function(e) event_meetup_to_df(e$node, group_urlname))
  events <- Filter(
    function(e) {
      !is.null(e) && e$date >= as.Date(substr(since, 1, 10))
    },
    events
  )

  if (length(events) == 0) {
    return(event_empty_df())
  }

  do.call(rbind, events)
}

#' Convert a Meetup GraphQL event node to a data frame row
#'
#' @param node List from Meetup GraphQL response.
#' @param group_urlname Group URL name used as chapter identifier.
#' @return Single-row data frame, or `NULL` if node is invalid.
#' @noRd
event_meetup_to_df <- function(node, group_urlname) {
  if (is.null(node) || is.null(node$title)) {
    return(NULL)
  }

  data.frame(
    title = node$title,
    date = as.Date(substr(node$dateTime %||% "", 1, 10)),
    url = node$eventUrl %||% NA_character_,
    rsvp_count = as.integer(node$going %||% 0L),
    source = "meetup",
    chapter = group_urlname,
    stringsAsFactors = FALSE
  )
}
