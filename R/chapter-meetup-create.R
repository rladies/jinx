#' Marker holding a pending Meetup draft on an onboarding issue
#'
#' A draft is created in one command and published in another, and
#' Meetup exposes no way to list drafts - neither `Query` nor `Member`
#' has a `groupDrafts` field - so the token that identifies it has to be
#' kept somewhere between the two runs.
#'
#' It lives on the issue rather than in KV because it is an identifier,
#' not a credential: the GraphQL endpoint authenticates every request
#' against the RLadies+ Pro account, so the token publishes nothing
#' without jinx's own Meetup credentials.
#' @keywords internal
#' @noRd
chapter_meetup_draft_marker <- function() "<!-- jinx:meetup-draft"

#' Render a pending draft as a machine-readable issue block
#' @keywords internal
#' @noRd
chapter_meetup_draft_render <- function(token, urlname, name) {
  json <- as.character(jsonlite::toJSON(
    list(
      token = jsonlite::unbox(token),
      urlname = jsonlite::unbox(urlname),
      name = jsonlite::unbox(name)
    ),
    pretty = TRUE,
    auto_unbox = FALSE
  ))
  paste0(chapter_meetup_draft_marker(), "\n", json, "\n-->")
}

#' Recover a pending draft from an onboarding issue body
#' @keywords internal
#' @noRd
chapter_meetup_draft_parse <- function(body) {
  body <- body %or% ""
  marker <- chapter_meetup_draft_marker()
  if (!grepl(marker, body, fixed = TRUE)) {
    return(NULL)
  }
  after <- sub(paste0("(?s)^.*?", marker), "", body, perl = TRUE)
  json <- sub("(?s)-->.*$", "", after, perl = TRUE)
  parsed <- tryCatch(
    jsonlite::fromJSON(json, simplifyVector = TRUE),
    error = function(e) {
      cli::cli_alert_warning("Onboarding issue has an unreadable draft block")
      NULL
    }
  )
  if (is.null(parsed) || is.null(parsed$token)) {
    return(NULL)
  }
  list(
    token = parsed$token,
    urlname = parsed$urlname %or% NULL,
    name = parsed$name %or% NULL
  )
}

#' Strip a pending draft block out of an issue body
#' @keywords internal
#' @noRd
chapter_meetup_draft_strip <- function(body) {
  marker <- chapter_meetup_draft_marker()
  if (!grepl(marker, body %or% "", fixed = TRUE)) {
    return(body)
  }
  trimws(gsub(
    paste0("(?s)\\n*", marker, ".*?-->"),
    "",
    body,
    perl = TRUE
  ))
}

#' Replace the draft block on an onboarding issue
#' @keywords internal
#' @noRd
chapter_meetup_draft_store <- function(
  issue_number,
  block,
  org,
  onboarding_repo
) {
  issue <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number
  )
  body <- chapter_meetup_draft_strip(issue$body %or% "")
  if (!is.null(block)) {
    body <- paste0(body, "\n\n", block)
  }
  gh::gh(
    "PATCH /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number,
    body = body
  )
  invisible(body)
}

#' Abort when a Meetup payload carried errors
#' @keywords internal
#' @noRd
chapter_meetup_check_errors <- function(payload, what) {
  errors <- payload$errors %or% NULL
  if (is.null(errors) || !length(errors)) {
    return(invisible(NULL))
  }
  messages <- vapply(
    errors,
    function(e) e$message %or% "no reason given",
    character(1)
  )
  cli::cli_abort(c(
    "Meetup refused to {what}.",
    stats::setNames(messages, rep("x", length(messages)))
  ))
}

#' Draft a chapter's Meetup group
#'
#' Builds the group from the onboarding issue - the standard name,
#' urlname and description, and the city's own coordinates - and leaves
#' it as a *draft*, which creates nothing public. Publishing is a
#' separate, deliberate command: see [chapter_meetup_publish()].
#'
#' Topics are left unset. They are the one part of a group that is a
#' judgement call rather than a derivation, and the @rladies/meetup-pro
#' team picks them in the Meetup UI.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The draft token (invisibly).
#' @export
chapter_meetup_draft <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  meta <- chapter_meta_fetch(issue_number, org, onboarding_repo)
  if (is.null(meta$city) || is.null(meta$country)) {
    cli::cli_abort(c(
      "Issue #{issue_number} carries no readable chapter details.",
      "i" = "Only issues jinx opened can be drafted from."
    ))
  }

  existing <- chapter_meetup_draft_parse(
    gh::gh(
      "GET /repos/{owner}/{repo}/issues/{issue_number}",
      owner = org,
      repo = onboarding_repo,
      issue_number = issue_number
    )$body
  )
  if (!is.null(existing)) {
    urlname <- existing$urlname
    cli::cli_abort(c(
      "Issue #{issue_number} already has a draft for {.val {urlname}}.",
      "i" = "Publish it with {.code /jinx chapter-meetup-publish}."
    ))
  }

  urlname <- chapter_meetup_urlname(meta$city)
  status <- meetup_urlname_status(urlname)
  if (identical(status, "taken")) {
    cli::cli_abort(c(
      "The urlname {.val {urlname}} is already taken on Meetup.",
      "i" = "A human needs to choose another one."
    ))
  }

  point <- geocode_city(meta$city, meta$country, meta$region)
  if (is.null(point)) {
    cli::cli_abort(c(
      "Could not geocode {meta$city}, {meta$country}.",
      "i" = "Meetup needs coordinates to place the group."
    ))
  }

  name <- chapter_meetup_name(meta$city)
  description <- meetup_description_text()

  result <- meetupr::meetupr_query(
    "mutation($input: CreateGroupDraftInput!) {
       createGroupDraft(input: $input) {
         token
         errors { message }
       }
     }",
    input = list(
      name = name,
      urlname = urlname,
      description = description,
      location = list(
        pointLocation = list(
          latitude = unname(point[["lat"]]),
          longitude = unname(point[["lon"]])
        )
      )
    )
  )

  payload <- result$data$createGroupDraft %or% list()
  chapter_meetup_check_errors(payload, "draft the group")
  token <- payload$token %or% NULL
  if (is.null(token)) {
    cli::cli_abort("Meetup returned no draft token for {.val {urlname}}")
  }

  chapter_meetup_draft_store(
    issue_number,
    chapter_meetup_draft_render(token, urlname, name),
    org,
    onboarding_repo
  )

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    chapter_meetup_draft_body(name, urlname, status, point)
  )

  cli::cli_alert_success("Drafted {.val {urlname}}")
  invisible(token)
}

#' Render the draft summary comment
#' @keywords internal
#' @noRd
chapter_meetup_draft_body <- function(name, urlname, status, point) {
  paste0(
    "## Meetup group drafted\n\n",
    "Nothing is public yet - this is a draft, and publishing it is a ",
    "separate command.\n\n",
    "| | |\n| --- | --- |\n",
    "| Name | ",
    name,
    " |\n",
    "| URL | `meetup.com/",
    urlname,
    "` |\n",
    "| urlname check | ",
    meetup_status_line(status, urlname),
    " |\n",
    "| Coordinates | ",
    round(point[["lat"]], 4),
    ", ",
    round(point[["lon"]], 4),
    " |\n",
    "| Topics | not set - @rladies/meetup-pro picks these |\n\n",
    "@rladies/meetup-pro: check the name and placement, then publish it ",
    "with `/jinx chapter-meetup-publish` on this issue. ",
    "Publishing creates the real group and cannot be undone from here."
  )
}

#' Publish a chapter's drafted Meetup group
#'
#' The irreversible half, kept as its own command so a human reads the
#' draft before the group exists. Reads the draft token off the
#' onboarding issue, publishes, records the group URL, and clears the
#' pending block.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return The group's urlname (invisibly).
#' @export
chapter_meetup_publish <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  issue <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number
  )
  draft <- chapter_meetup_draft_parse(issue$body)
  if (is.null(draft)) {
    cli::cli_abort(c(
      "Issue #{issue_number} has no drafted Meetup group.",
      "i" = "Draft one first with {.code /jinx chapter-meetup-draft}."
    ))
  }

  result <- meetupr::meetupr_query(
    "mutation($input: PublishGroupDraftInput!) {
       publishGroupDraft(input: $input) {
         group { urlname name link }
         errors { message }
       }
     }",
    input = list(token = draft$token)
  )

  payload <- result$data$publishGroupDraft %or% list()
  chapter_meetup_check_errors(payload, "publish the group")
  group <- payload$group %or% list()
  urlname <- group$urlname %or% draft$urlname
  link <- group$link %or% paste0("https://www.meetup.com/", urlname, "/")

  chapter_meetup_draft_store(issue_number, NULL, org, onboarding_repo)

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    paste0(
      "## Meetup group is live\n\n",
      group$name %or% draft$name,
      " is published: ",
      link,
      "\n\nNext: `/jinx chapter-provision` picks the urlname up from this ",
      "comment and creates the GitHub team.\n\n",
      chapter_thread_live_marker()
    )
  )

  chapter_checklist_tick(
    issue_number,
    "create the city chapter on Meetup",
    org = org,
    onboarding_repo = onboarding_repo
  )

  cli::cli_alert_success("Published {.val {urlname}}")
  invisible(urlname)
}
