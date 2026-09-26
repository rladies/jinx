#' The GitHub team slug for a chapter
#'
#' The Meetup urlname, minus the `rladies-` prefix. This is the
#' convention 108 of the 122 existing chapter teams already follow, and
#' it is the only chapter field that is unique: seven city names are
#' shared by more than one chapter, and it is the urlname that separates
#' them - `london` from `ldnont`, `pdx` from `portland-maine`.
#'
#' @param urlname Meetup urlname, with or without the `rladies-` prefix.
#' @param overrides Named character vector mapping a urlname to a slug,
#'   for chapters whose urlname makes a poor team name. Warsaw's is
#'   `Spotkania-Entuzjastow-R-Warsaw-R-Users-Group-Meetup`.
#' @return The team slug, or `NA_character_` when there is no urlname.
#' @export
chapter_team_slug <- function(urlname, overrides = character(0)) {
  if (is.null(urlname) || !nzchar(urlname %or% "")) {
    return(NA_character_)
  }
  if (urlname %in% names(overrides)) {
    return(unname(overrides[[urlname]]))
  }
  chapter_slug(sub("^rladies-", "", tolower(urlname)))
}

#' The display name for a chapter's GitHub team
#'
#' GitHub derives a team's slug from its name and gives no way to set the
#' slug directly, so the name has to be chosen such that it slugifies
#' back to the chapter's urlname. That rules out "Portland, Oregon, USA"
#' as a name - it would produce `portland-oregon-usa` rather than `pdx`.
#'
#' The readable description of the chapter goes in the team's
#' description instead, which is free text and does not affect the slug.
#'
#' @param slug Team slug, from [chapter_team_slug()].
#' @param acronyms Slugs to render upper case rather than title case.
#' @return The display name.
#' @export
chapter_team_name <- function(slug, acronyms = chapter_team_acronyms()) {
  if (is.null(slug) || is.na(slug) || !nzchar(slug)) {
    cli::cli_abort("Cannot build a team name without a slug")
  }
  if (slug %in% acronyms) {
    return(toupper(slug))
  }
  words <- strsplit(slug, "-", fixed = TRUE)[[1]]
  words <- vapply(
    words,
    function(w) {
      if (w %in% acronyms) {
        toupper(w)
      } else {
        paste0(toupper(substring(w, 1, 1)), substring(w, 2))
      }
    },
    character(1)
  )
  paste(words, collapse = " ")
}

#' Slugs conventionally written upper case
#'
#' The org already has teams named RTP, DC, LA and NYC; title-casing
#' those would read as words rather than places.
#' @keywords internal
#' @noRd
chapter_team_acronyms <- function() {
  c("rtp", "dc", "la", "nyc", "pdx", "uk", "usa", "ga", "gr", "ky", "sg", "ma")
}

#' The chapter description shown on the team
#'
#' Free text, so unlike the name it can spell the chapter out in full
#' without changing the slug.
#'
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province, or `NULL`.
#' @return The description.
#' @export
chapter_team_description <- function(city, country, region = NULL) {
  if (is.null(city) || is.na(city) || !nzchar(city)) {
    cli::cli_abort("Cannot describe a team without a city")
  }
  parts <- c(city, region, country)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  paste0("RLadies+ chapter in ", paste(parts, collapse = ", "))
}

#' Would GitHub derive the slug we want from this name?
#'
#' GitHub lowercases, strips punctuation and hyphenates spaces. If the
#' round trip does not come back to the slug we asked for, the team would
#' be created at the wrong address.
#'
#' @param name Proposed team name.
#' @param slug Slug the name must produce.
#' @return `TRUE`, invisibly; aborts otherwise.
#' @keywords internal
#' @noRd
chapter_team_name_check <- function(name, slug) {
  derived <- chapter_slug(name)
  if (!identical(derived, slug)) {
    cli::cli_abort(c(
      "The team name {.val {name}} would not produce the slug {.val {slug}}.",
      "x" = "GitHub would derive {.val {derived}} instead."
    ))
  }
  invisible(TRUE)
}

#' List the chapter teams nested under the parent team
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param parent_team Slug of the parent team.
#' @return A data frame with `slug` and `display`.
#' @keywords internal
#' @noRd
chapter_teams_fetch <- function(org = "rladies", parent_team = "chapters") {
  teams <- gh::gh(
    "GET /orgs/{org}/teams/{team_slug}/teams",
    org = org,
    team_slug = parent_team,
    .limit = Inf
  )
  if (length(teams) == 0) {
    return(data.frame(
      slug = character(0),
      display = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    slug = vapply(teams, function(t) t$slug, character(1)),
    display = vapply(teams, function(t) t$name, character(1)),
    stringsAsFactors = FALSE
  )
}

#' Compare the chapter teams against the website chapter data
#'
#' Reports rather than repairs. Renaming a team changes its URL and where
#' its notifications go, so which of these to act on is a human decision.
#'
#' Each row is one of:
#' * `ok` - the team matches a chapter's urlname
#' * `slug_mismatch` - a chapter matches by city, but its urlname would
#'   give a different slug
#' * `no_chapter` - no chapter in the website data explains this team
#' * `missing_team` - an active chapter with a Meetup group and no team
#'
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param website_repo Repository holding `data/chapters`.
#' @param parent_team Slug of the parent team.
#' @param statuses Chapter statuses expected to have a team.
#' @return A data frame with `finding`, `team`, `display`, `chapter`, and
#'   `expected_slug`.
#' @export
chapter_team_audit <- function(
  org = "rladies",
  website_repo = "rladies.github.io",
  parent_team = "chapters",
  statuses = "active"
) {
  teams <- chapter_teams_fetch(org, parent_team)
  chapters <- chapter_team_chapters(org, website_repo)

  rows <- c(
    lapply(seq_len(nrow(teams)), function(i) {
      chapter_team_finding(teams[i, ], chapters)
    }),
    chapter_team_missing(teams, chapters, statuses)
  )

  audit <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(audit)) {
    return(chapter_team_audit_empty())
  }
  audit <- audit[order(audit$finding, audit$team), ]
  row.names(audit) <- NULL
  audit
}

#' Chapter rows the audit compares against
#' @keywords internal
#' @noRd
chapter_team_chapters <- function(org, website_repo) {
  files <- chapter_index_fetch(org, website_repo)
  entries <- lapply(files, chapter_entry_fetch, org = org, repo = website_repo)
  entries <- Filter(Negate(is.null), entries)

  rows <- lapply(entries, function(entry) {
    urlname <- entry$urlname %or%
      ((entry$social_media %or% list())$meetup %or% NULL)
    data.frame(
      city = entry$city %or% NA_character_,
      country = entry$country %or% NA_character_,
      status = entry$status %or% NA_character_,
      cityslug = chapter_slug(entry$city),
      expected = chapter_team_slug(urlname),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Classify one existing team against the chapter data
#' @keywords internal
#' @noRd
chapter_team_finding <- function(team, chapters) {
  matched <- chapters[
    !is.na(chapters$expected) & chapters$expected == team$slug,
  ]
  if (nrow(matched) > 0) {
    return(chapter_team_row(
      "ok",
      team$slug,
      team$display,
      matched[1, ],
      team$slug
    ))
  }

  by_city <- chapters[chapters$cityslug == team$slug, ]
  if (nrow(by_city) > 0) {
    return(chapter_team_row(
      "slug_mismatch",
      team$slug,
      team$display,
      by_city[1, ],
      by_city$expected[1] %or% NA_character_
    ))
  }

  chapter_team_row("no_chapter", team$slug, team$display, NULL, NA_character_)
}

#' Chapters of the given statuses that have no team
#' @keywords internal
#' @noRd
chapter_team_missing <- function(teams, chapters, statuses) {
  wanted <- chapters[
    chapters$status %in% statuses & !is.na(chapters$expected),
  ]
  wanted <- wanted[!wanted$expected %in% teams$slug, ]
  lapply(seq_len(nrow(wanted)), function(i) {
    chapter_team_row(
      "missing_team",
      NA_character_,
      NA_character_,
      wanted[i, ],
      wanted$expected[i]
    )
  })
}

chapter_team_row <- function(finding, team, display, chapter, expected) {
  data.frame(
    finding = finding,
    team = team %or% NA_character_,
    display = display %or% NA_character_,
    chapter = if (is.null(chapter)) {
      NA_character_
    } else {
      paste(chapter$city, chapter$country, sep = ", ")
    },
    expected_slug = expected %or% NA_character_,
    stringsAsFactors = FALSE
  )
}

chapter_team_audit_empty <- function() {
  data.frame(
    finding = character(0),
    team = character(0),
    display = character(0),
    chapter = character(0),
    expected_slug = character(0),
    stringsAsFactors = FALSE
  )
}

#' Render a team audit as markdown
#'
#' @param audit Data frame from [chapter_team_audit()].
#' @return Markdown body as a single string.
#' @export
chapter_team_audit_report <- function(audit) {
  counts <- table(factor(
    audit$finding,
    levels = c("ok", "slug_mismatch", "no_chapter", "missing_team")
  ))

  n_ok <- counts[["ok"]]
  n_missing <- counts[["missing_team"]]
  header <- paste0(
    "## Chapter team audit\n\n",
    "- ",
    n_ok,
    if (n_ok == 1) " team matches" else " teams match",
    " a chapter's Meetup urlname\n",
    "- ",
    counts[["slug_mismatch"]],
    " named differently from the chapter's urlname\n",
    "- ",
    counts[["no_chapter"]],
    " with no chapter in the website data\n",
    "- ",
    n_missing,
    if (n_missing == 1) " active chapter" else " active chapters",
    " with a group and no team\n\n",
    "Renaming a team changes its URL and where its notifications go, so ",
    "these are reported rather than fixed.\n"
  )

  sections <- vapply(
    c("slug_mismatch", "no_chapter", "missing_team"),
    function(kind) chapter_team_section(audit, kind),
    character(1)
  )
  paste0(header, paste(sections[nzchar(sections)], collapse = ""))
}

#' One section of the audit report
#' @keywords internal
#' @noRd
chapter_team_section <- function(audit, kind) {
  rows <- audit[audit$finding == kind, ]
  if (nrow(rows) == 0) {
    return("")
  }
  titles <- c(
    slug_mismatch = "### Named differently from the chapter's urlname",
    no_chapter = "### No chapter in the website data explains these",
    missing_team = "### Active chapters with a Meetup group and no team"
  )
  bullets <- vapply(
    seq_len(nrow(rows)),
    function(i) {
      r <- rows[i, ]
      if (kind == "missing_team") {
        glue::glue("- **{r$chapter}** - would be `{r$expected_slug}`")
      } else if (kind == "no_chapter") {
        glue::glue("- `{r$team}` ({r$display})")
      } else {
        glue::glue(
          "- `{r$team}` ({r$display}) - {r$chapter} uses ",
          "`{r$expected_slug %or% 'no urlname'}`"
        )
      }
    },
    character(1)
  )
  paste0("\n", titles[[kind]], "\n\n", paste(bullets, collapse = "\n"), "\n")
}

#' Create a chapter's GitHub team
#'
#' Creates the team nested under the `chapters` parent, named so that its
#' slug matches the chapter's Meetup urlname, with the chapter spelled
#' out in the description.
#'
#' @param urlname Meetup urlname for the chapter.
#' @param city Chapter city.
#' @param country Chapter country.
#' @param region State/region/province, or `NULL`.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param parent_team Slug of the parent team.
#' @param overrides Passed to [chapter_team_slug()].
#' @return The created team's slug (invisibly).
#' @export
chapter_team_create <- function(
  urlname,
  city,
  country,
  region = NULL,
  org = "rladies",
  parent_team = "chapters",
  overrides = character(0)
) {
  slug <- chapter_team_slug(urlname, overrides)
  if (is.na(slug)) {
    cli::cli_abort(c(
      "Cannot create a team for {.val {city}} without a Meetup urlname.",
      "i" = "The urlname is what makes the team slug unique."
    ))
  }

  name <- chapter_team_name(slug)
  chapter_team_name_check(name, slug)

  existing <- chapter_teams_fetch(org, parent_team)
  if (slug %in% existing$slug) {
    cli::cli_alert_info("Team {.val {slug}} already exists")
    return(invisible(slug))
  }

  team <- gh::gh(
    "POST /orgs/{org}/teams",
    org = org,
    name = name,
    description = chapter_team_description(city, country, region),
    parent_team_id = chapter_parent_team_id(org, parent_team),
    privacy = "closed"
  )

  if (!identical(team$slug, slug)) {
    cli::cli_alert_warning(
      "GitHub created {.val {team$slug}}, not {.val {slug}}"
    )
  }

  cli::cli_alert_success("Created team {.val {team$slug}} ({name})")
  invisible(team$slug)
}

#' The numeric id of the parent team
#' @keywords internal
#' @noRd
chapter_parent_team_id <- function(org, parent_team) {
  parent <- gh::gh(
    "GET /orgs/{org}/teams/{team_slug}",
    org = org,
    team_slug = parent_team
  )
  parent$id
}
