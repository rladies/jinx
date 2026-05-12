#' Recommend a speaker for a conference
#'
#' Adds a speaker recommendation as a comment on the CFP tracking issue.
#'
#' @param conference Conference name (matched against open CFP issues).
#' @param speaker_name Speaker name or GitHub username.
#' @param speaker_github Optional GitHub username.
#' @param expertise Character vector of expertise areas.
#' @param org GitHub organization.
#' @param repo Repository where CFP issues are tracked.
#' @return Comment URL (invisibly).
#' @export
recommend_speaker <- function(
  conference,
  speaker_name,
  speaker_github = NULL,
  expertise = character(0),
  org = "rladies",
  repo = "global-team"
) {
  cfps <- list_open_cfps(org = org, repo = repo)

  matched <- cfps[grepl(conference, cfps$conference, ignore.case = TRUE), ]
  if (nrow(matched) == 0) {
    cli::cli_abort("No open CFP found matching '{conference}'")
  }

  issue_number <- matched$number[1]

  template_path <- system.file(
    "templates",
    "speaker-recommendation.md",
    package = "jinx"
  )

  speaker_ref <- if (!is.null(speaker_github)) {
    cli::format_inline("@{speaker_github}")
  } else {
    speaker_name
  }

  expertise_str <- if (length(expertise) > 0) {
    toString(expertise)
  } else {
    "Not specified"
  }

  body <- if (nzchar(template_path)) {
    render_template(
      template_path,
      list(
        CONFERENCE = matched$conference[1],
        SPEAKER = speaker_ref,
        EXPERTISE = expertise_str
      )
    )
  } else {
    cli::format_inline(paste0(
      "### Speaker Recommendation\n\n",
      "**Speaker**: {speaker_ref}\n",
      "**Expertise**: {expertise_str}\n",
      "**Conference**: {matched$conference[1]}"
    ))
  }

  comment <- gh::gh(
    "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = repo,
    issue_number = issue_number,
    body = body
  )

  cli::cli_alert_success(
    "Speaker recommendation added for {speaker_name} to {matched$conference[1]}"
  )
  invisible(comment$html_url)
}

#' List speaker recommendations for a conference
#'
#' @param conference Conference name.
#' @param org GitHub organization.
#' @param repo Repository where CFP issues are tracked.
#' @return Data frame with columns: speaker, expertise, recommended_by.
#' @export
list_speaker_recommendations <- function(
  conference,
  org = "rladies",
  repo = "global-team"
) {
  cfps <- list_open_cfps(org = org, repo = repo)
  matched <- cfps[grepl(conference, cfps$conference, ignore.case = TRUE), ]

  if (nrow(matched) == 0) {
    return(data.frame(
      speaker = character(0),
      expertise = character(0),
      recommended_by = character(0),
      stringsAsFactors = FALSE
    ))
  }

  comments <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = repo,
    issue_number = matched$number[1],
    .limit = Inf
  )

  recs <- Filter(
    function(c) grepl("Speaker Recommendation", c$body %||% "", fixed = TRUE),
    comments
  )

  if (length(recs) == 0) {
    return(data.frame(
      speaker = character(0),
      expertise = character(0),
      recommended_by = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(recs, function(c) {
    speaker <- extract_field(c$body, "Speaker")
    expertise <- extract_field(c$body, "Expertise")
    data.frame(
      speaker = speaker %||% NA_character_,
      expertise = expertise %||% NA_character_,
      recommended_by = c$user$login %||% NA_character_,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

extract_field <- function(body, field) {
  lines <- strsplit(body, "\n")[[1]]
  pattern <- paste0("\\*\\*", field, "\\*\\*:\\s*(.+)")
  for (line in lines) {
    match <- regmatches(line, regexec(pattern, line))[[1]]
    if (length(match) >= 2) return(trimws(match[2]))
  }
  NULL
}
