#' Check whether a requested chapter already exists or has neighbours
#'
#' Performs the first step of the chapter onboarding checklist: searches
#' the website's `data/chapters` entries for a chapter in the same city,
#' for chapters with a near-identical city name, and for chapters in the
#' same country within `radius_km` of the requested city.
#'
#' Only chapters in the requested country, or whose filename contains the
#' requested city slug, are fetched in full, so the check costs one
#' directory listing plus a handful of file reads.
#'
#' @param city Requested chapter city.
#' @param country Requested chapter country.
#' @param region State/region/province, or `NULL`.
#' @param radius_km Radius in kilometres for the proximity search. Set to
#'   `NULL` to skip geocoding entirely.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param website_repo Repository holding `data/chapters`.
#' @return A data frame with one row per match and columns `city`,
#'   `country`, `status`, `email`, `meetup`, `match`, and `distance_km`.
#'   `match` is one of `"exact"`, `"similar"`, or `"nearby"`.
#' @export
chapter_duplicate_check <- function(
  city,
  country,
  region = NULL,
  radius_km = 100,
  org = "rladies",
  website_repo = "rladies.github.io"
) {
  city_slug <- chapter_slug(city)
  country_slug <- chapter_slug(country)

  files <- chapter_index_fetch(org, website_repo)
  files <- chapter_candidate_files(files, city_slug, country_slug)

  entries <- lapply(files, chapter_entry_fetch, org = org, repo = website_repo)
  entries <- Filter(Negate(is.null), entries)

  matches <- chapter_match_table(entries, city_slug, country_slug)
  matches <- chapter_add_distances(matches, city, country, region, radius_km)

  matches <- matches[!is.na(matches$match), ]
  matches <- matches[order(matches$match, matches$city), ]
  row.names(matches) <- NULL
  matches
}

#' List the chapter filenames on the website
#' @keywords internal
#' @noRd
chapter_index_fetch <- function(org, website_repo) {
  entries <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/data/chapters",
    owner = org,
    repo = website_repo,
    .limit = Inf
  )
  names <- vapply(entries, function(entry) entry$name, character(1))
  names[grepl("\\.json$", names)]
}

#' Narrow the chapter index to files worth fetching in full
#'
#' Keeps every chapter in the requested country, plus any chapter
#' anywhere whose filename carries the requested city slug as a
#' hyphen-delimited token.
#' @keywords internal
#' @noRd
chapter_candidate_files <- function(files, city_slug, country_slug) {
  same_country <- startsWith(files, paste0(country_slug, "-"))
  same_city <- grepl(
    paste0("(^|-)", city_slug, "(-|\\.json$)"),
    files,
    perl = TRUE
  )
  files[same_country | same_city]
}

#' Read one chapter entry from the website's raw content
#' @keywords internal
#' @noRd
chapter_entry_fetch <- function(file, org, repo) {
  url <- glue::glue(
    "https://raw.githubusercontent.com/{org}/{repo}/main/data/chapters/{file}"
  )
  entry <- tryCatch(
    jsonlite::fromJSON(url, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_alert_warning("Could not read chapter file {.file {file}}")
      NULL
    }
  )
  if (is.null(entry)) {
    return(NULL)
  }
  entry$file <- file
  entry
}

#' Classify candidate chapters against the requested city and country
#' @keywords internal
#' @noRd
chapter_match_table <- function(entries, city_slug, country_slug) {
  if (length(entries) == 0) {
    return(chapter_match_empty())
  }

  table <- do.call(rbind, lapply(entries, chapter_match_row))
  table$match <- mapply(
    chapter_match_kind,
    table$city_slug,
    table$country_slug,
    MoreArgs = list(city_slug = city_slug, country_slug = country_slug),
    USE.NAMES = FALSE
  )
  table
}

#' One row of the match table, flattened from a chapter entry
#' @keywords internal
#' @noRd
chapter_match_row <- function(entry) {
  social <- entry$social_media %or% list()
  data.frame(
    file = entry$file,
    city = entry$city %or% NA_character_,
    country = entry$country %or% NA_character_,
    status = entry$status %or% NA_character_,
    email = social$email %or% NA_character_,
    meetup = social$meetup %or% NA_character_,
    city_slug = chapter_slug(entry$city),
    country_slug = chapter_slug(entry$country),
    distance_km = NA_real_,
    stringsAsFactors = FALSE
  )
}

#' Decide how a candidate relates to the requested chapter
#'
#' Same city and country is `"exact"`; the same city name elsewhere, or a
#' near-identical name in the same country, is `"similar"`. Everything
#' else is left `NA` for the proximity pass to classify.
#' @keywords internal
#' @noRd
chapter_match_kind <- function(
  entry_city,
  entry_country,
  city_slug,
  country_slug
) {
  if (!nzchar(entry_city) || !nzchar(city_slug)) {
    return(NA_character_)
  }
  same_country <- identical(entry_country, country_slug)
  if (identical(entry_city, city_slug)) {
    return(if (same_country) "exact" else "similar")
  }
  near_name <- as.integer(utils::adist(entry_city, city_slug)) <= 2
  if (same_country && near_name) {
    return("similar")
  }
  NA_character_
}

#' Fill in distances for same-country chapters and flag the near ones
#' @keywords internal
#' @noRd
chapter_add_distances <- function(
  matches,
  city,
  country,
  region,
  radius_km
) {
  pending <- is.na(matches$match) & !is.na(matches$city)
  if (is.null(radius_km) || !any(pending)) {
    return(matches)
  }

  origin <- geocode_city(city, country, region)
  if (is.null(origin)) {
    cli::cli_alert_warning(
      "Could not geocode {city}, {country} - skipping the proximity check"
    )
    return(matches)
  }

  for (i in which(pending)) {
    point <- geocode_city(matches$city[i], matches$country[i])
    if (is.null(point)) {
      next
    }
    matches$distance_km[i] <- haversine_km(origin, point)
  }

  near <- pending &
    !is.na(matches$distance_km) &
    matches$distance_km <= radius_km
  matches$match[near] <- "nearby"
  matches
}

#' Empty match table with the documented columns
#' @keywords internal
#' @noRd
chapter_match_empty <- function() {
  data.frame(
    file = character(0),
    city = character(0),
    country = character(0),
    status = character(0),
    email = character(0),
    meetup = character(0),
    city_slug = character(0),
    country_slug = character(0),
    distance_km = numeric(0),
    match = character(0),
    stringsAsFactors = FALSE
  )
}

#' Look up a place's coordinates via Nominatim
#'
#' Results are cached for the session, and the endpoint is throttled to
#' the one request per second that Nominatim's usage policy requires.
#' Returns `NULL` when the place cannot be resolved.
#' @keywords internal
#' @noRd
geocode_city <- function(city, country, region = NULL) {
  key <- chapter_slug(country, region, city)
  cached <- geocode_cache[[key]]
  if (!is.null(cached)) {
    return(cached$value)
  }

  query <- list(
    city = city,
    state = region,
    country = country,
    format = "json",
    limit = 1
  )
  query <- query[!vapply(query, is.null, logical(1))]

  result <- tryCatch(
    httr2::request("https://nominatim.openstreetmap.org") |>
      httr2::req_url_path_append("search") |>
      httr2::req_url_query(!!!query) |>
      httr2::req_user_agent(geocode_user_agent()) |>
      httr2::req_throttle(capacity = 1, fill_time_s = 1) |>
      httr2::req_perform() |>
      httr2::resp_body_json(),
    error = function(e) NULL
  )

  value <- geocode_first_point(result)
  geocode_cache[[key]] <- list(value = value)
  value
}

geocode_cache <- new.env(parent = emptyenv())

geocode_user_agent <- function() {
  "jinx chapter onboarding (https://github.com/rladies/jinx)"
}

#' Pull the first lat/lon pair out of a Nominatim response
#' @keywords internal
#' @noRd
geocode_first_point <- function(result) {
  if (is.null(result) || length(result) == 0) {
    return(NULL)
  }
  first <- result[[1]]
  lat <- suppressWarnings(as.numeric(first$lat))
  lon <- suppressWarnings(as.numeric(first$lon))
  if (is.na(lat) || is.na(lon)) {
    return(NULL)
  }
  c(lat = lat, lon = lon)
}

#' Great-circle distance in kilometres between two lat/lon points
#' @keywords internal
#' @noRd
haversine_km <- function(from, to) {
  radians <- pi / 180
  d_lat <- (to[["lat"]] - from[["lat"]]) * radians
  d_lon <- (to[["lon"]] - from[["lon"]]) * radians
  a <- sin(d_lat / 2)^2 +
    cos(from[["lat"]] * radians) *
      cos(to[["lat"]] * radians) *
      sin(d_lon / 2)^2
  6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
}

#' Render a duplicate check as an onboarding issue comment
#'
#' Turns the output of [chapter_duplicate_check()] into the markdown the
#' onboarding team reads first: whether the city already has a chapter,
#' which nearby chapters should be cc'd, and which names are close enough
#' to be worth a second look.
#'
#' @param matches Data frame from [chapter_duplicate_check()].
#' @param city Requested chapter city.
#' @param country Requested chapter country.
#' @param radius_km Radius used for the proximity search.
#' @return Markdown body as a single string.
#' @export
chapter_duplicate_report <- function(
  matches,
  city,
  country,
  radius_km = 100
) {
  header <- glue::glue(
    "## Duplicate check: {city}, {country}\n\n",
    "Searched the chapters on the website for an existing chapter in ",
    "this city, for near-identical city names, and for chapters within ",
    "{radius_km} km.\n"
  )

  if (nrow(matches) == 0) {
    return(paste0(
      header,
      "\nNo existing or nearby chapter found. ",
      "Safe to continue with onboarding.\n"
    ))
  }

  sections <- c(
    chapter_report_section(matches, "exact"),
    chapter_report_section(matches, "nearby"),
    chapter_report_section(matches, "similar")
  )
  paste0(header, "\n", paste(sections, collapse = "\n"))
}

chapter_report_headings <- function() {
  list(
    exact = list(
      title = "### This city already has a chapter",
      note = paste(
        "Reply to the sender to let them know, and put them in touch",
        "with the organizers by cc'ing the chapter email."
      )
    ),
    nearby = list(
      title = "### Nearby chapters",
      note = "Consider connecting the sender with these organizers."
    ),
    similar = list(
      title = "### Similar chapter names",
      note = paste(
        "Worth a look in case this is the same city spelled",
        "differently."
      )
    )
  )
}

#' Render one match-kind section of the duplicate report
#' @keywords internal
#' @noRd
chapter_report_section <- function(matches, kind) {
  rows <- matches[matches$match == kind, ]
  if (nrow(rows) == 0) {
    return(character(0))
  }
  rows <- rows[order(rows$distance_km, rows$city), ]
  heading <- chapter_report_headings()[[kind]]
  bullets <- vapply(
    seq_len(nrow(rows)),
    function(i) {
      chapter_report_bullet(rows[i, ])
    },
    character(1)
  )
  paste0(
    heading$title,
    "\n\n",
    paste(bullets, collapse = "\n"),
    "\n\n",
    heading$note,
    "\n"
  )
}

#' One bullet describing a matched chapter
#' @keywords internal
#' @noRd
chapter_report_bullet <- function(row) {
  details <- c(
    if (!is.na(row$status)) glue::glue("status {row$status}"),
    if (!is.na(row$email)) glue::glue("<{row$email}>"),
    if (!is.na(row$meetup)) {
      glue::glue("[meetup](https://www.meetup.com/{row$meetup}/)")
    },
    if (!is.na(row$distance_km)) {
      glue::glue("{round(row$distance_km)} km away")
    }
  )
  if (length(details) == 0) {
    return(glue::glue("- **{row$city}, {row$country}**"))
  }
  glue::glue(
    "- **{row$city}, {row$country}** - {paste(details, collapse = ', ')}"
  )
}

#' Post the duplicate check onto an onboarding issue
#'
#' Runs [chapter_duplicate_check()] and comments the rendered report on
#' the issue. Failures are reported but never abort onboarding: the
#' check is an aid to the team, not a gate.
#'
#' @param issue_number Onboarding issue number.
#' @param city Requested chapter city.
#' @param country Requested chapter country.
#' @param region State/region/province, or `NULL`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The rendered report (invisibly), or `NULL` on failure.
#' @export
chapter_duplicate_comment <- function(
  issue_number,
  city,
  country,
  region = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  body <- tryCatch(
    {
      matches <- chapter_duplicate_check(
        city = city,
        country = country,
        region = region,
        org = org
      )
      chapter_duplicate_report(matches, city, country)
    },
    error = function(e) {
      cli::cli_alert_warning("Duplicate check failed: {e$message}")
      NULL
    }
  )

  if (is.null(body)) {
    return(invisible(NULL))
  }

  gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number,
    body = body
  )

  cli::cli_alert_success("Duplicate check posted on issue #{issue_number}")
  invisible(body)
}
