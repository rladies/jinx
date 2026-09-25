#' List events from the Meetup GraphQL API
#'
#' Queries through `meetupr`, which owns the authentication: it signs the
#' JWT, exchanges it for a token, and targets the current `gql-ext`
#' endpoint. jinx previously hardcoded `api.meetup.com/gql`, which now
#' returns 404, and read a `MEETUP_API_KEY` that was never set - so this
#' path had never actually run (#152).
#'
#' Credentials are meetupr's own, resolved as `<client_name>_<key>`
#' environment variables: `meetupr_client_key`, `meetupr_jwt_issuer`
#' (the numeric member id) and `meetupr_jwt_token` (a PEM string or a
#' path to one), with the prefix taken from `MEETUPR_CLIENT_NAME`.
#'
#' @param group_urlname Meetup group URL name (e.g. "rladies-berlin").
#' @param months Number of months of history to fetch.
#' @return Data frame with columns: title, date, url, rsvp_count, source,
#'   chapter.
#' @noRd
event_meetup_list <- function(group_urlname, months = 3) {
  since <- as.Date(Sys.Date() - lubridate::dmonths(months))

  result <- meetupr::meetupr_query(
    '
    query($urlname: String!) {
      groupByUrlname(urlname: $urlname) {
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
    urlname = group_urlname
  )

  edges <- result$data$groupByUrlname$pastEvents$edges %||% list()
  events <- lapply(edges, function(e) event_meetup_to_df(e$node, group_urlname))
  events <- Filter(function(e) !is.null(e) && e$date >= since, events)

  if (length(events) == 0) {
    return(event_empty_df())
  }

  do.call(rbind, events)
}

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
