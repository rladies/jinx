#' Field labels the chapter intake forms ask for
#'
#' The keys are the field names jinx works in; the values are the
#' headings GitHub renders an issue form's answers under, which is the
#' only thing the submitted body carries.
#' @keywords internal
#' @noRd
chapter_intake_fields <- function() {
  c(
    city = "City",
    country = "Country",
    region = "State, province or region",
    organizers = "Prospective organisers"
  )
}

#' What GitHub writes where an optional form field was left blank
#' @keywords internal
#' @noRd
chapter_intake_blank <- function() "_No response_"

#' Split an issue-form body into its answers
#'
#' GitHub renders a submitted form as `### Label` followed by the
#' answer, which is the only structure there is to read: the form's own
#' field ids never reach the issue.
#'
#' @param body Issue body markdown.
#' @return A named character vector of answers, empty when the body is
#'   not a form submission.
#' @keywords internal
#' @noRd
chapter_form_parse <- function(body) {
  lines <- strsplit(body %or% "", "\r?\n", perl = TRUE)[[1]]
  heads <- grep("^###\\s+", lines)
  if (!length(heads)) {
    return(character(0))
  }

  labels <- trimws(sub("^###\\s+", "", lines[heads]))
  ends <- c(heads[-1] - 1L, length(lines))

  answers <- vapply(
    seq_along(heads),
    function(i) {
      chunk <- lines[seq(heads[i] + 1L, ends[i])]
      trimws(paste(chunk, collapse = "\n"))
    },
    character(1)
  )

  answers[identical(answers, chapter_intake_blank())] <- ""
  answers[answers == chapter_intake_blank()] <- ""
  stats::setNames(answers, labels)
}

#' Read the chapter's details off an intake form
#'
#' @param body Issue body markdown.
#' @return A list with `city`, `country`, `region` and `organizers`;
#'   each `NULL` when the form did not carry it.
#' @keywords internal
#' @noRd
chapter_intake_details <- function(body) {
  answers <- chapter_form_parse(body)
  fields <- chapter_intake_fields()

  value <- function(key) {
    found <- answers[[fields[[key]]]] %or% NULL
    if (is.null(found) || !nzchar(found)) NULL else found
  }

  organizers <- value("organizers")
  list(
    city = value("city"),
    country = value("country"),
    region = value("region"),
    organizers = if (is.null(organizers)) {
      character(0)
    } else {
      trimws(strsplit(organizers, "[,\n]")[[1]])
    }
  )
}

#' The two kinds of onboarding issue
#' @keywords internal
#' @noRd
chapter_intake_kinds <- function() {
  list(
    setup = list(
      label = "new chapter: first contact",
      template = "chapter-setup.md",
      suffix = "chapter setup"
    ),
    update = list(
      label = "updating chapter data",
      template = "chapter-update.md",
      suffix = "chapter update"
    )
  )
}

#' The label marking an onboarding issue of one kind
#'
#' These are the labels the onboarding repository actually has. Several
#' places used to name a `"new chapter"`/`"chapter update"` pair that
#' exists nowhere, which left [chapter_remind_stale()] searching for
#' labels no issue carries.
#'
#' @param kind `"setup"` or `"update"`.
#' @return The label name.
#' @keywords internal
#' @noRd
chapter_issue_label <- function(kind) {
  chapter_intake_kinds()[[kind]]$label
}

#' Every onboarding issue label
#' @keywords internal
#' @noRd
chapter_issue_labels <- function() {
  vapply(chapter_intake_kinds(), function(k) k$label, character(1))
}

#' Which kind of issue an intake form opened
#'
#' Read from the label the form itself applies, so the two forms stay
#' the single source of truth for which is which.
#'
#' @param labels Character vector of label names on the issue.
#' @return `"setup"`, `"update"`, or `NULL` when neither applies.
#' @keywords internal
#' @noRd
chapter_intake_kind <- function(labels) {
  kinds <- chapter_intake_kinds()
  for (name in names(kinds)) {
    if (kinds[[name]]$label %in% labels) {
      return(name)
    }
  }
  NULL
}

#' Compose the canonical issue body for an onboarding issue
#'
#' The checklist comes from the template bundled with jinx rather than
#' from a copy in the onboarding repository, so the steps the team works
#' through and the steps jinx ticks can never drift apart. The form only
#' has to collect the facts.
#'
#' @param kind `"setup"` or `"update"`.
#' @param details Chapter details from [chapter_intake_details()].
#' @return The issue body as a single string.
#' @keywords internal
#' @noRd
chapter_intake_body <- function(kind, details) {
  spec <- chapter_intake_kinds()[[kind]]
  checklist <- render_template(
    system.file("templates", spec$template, package = "jinx"),
    list(
      CITY = details$city,
      COUNTRY = details$country,
      ORGANIZERS = toString(details$organizers)
    )
  )
  paste0(
    checklist,
    "\n\n",
    chapter_meta_render(
      details$city,
      details$country,
      details$region,
      details$organizers
    )
  )
}

#' The title an onboarding issue should carry
#'
#' Matches the convention the team has used across every issue in the
#' repository, so the form's placeholder title never survives.
#' @keywords internal
#' @noRd
chapter_intake_title <- function(kind, details) {
  parts <- c(details$city, details$region, details$country)
  parts <- parts[!vapply(parts, is_blank, logical(1))]
  paste(
    paste(parts, collapse = ", "),
    chapter_intake_kinds()[[kind]]$suffix
  )
}

#' Take over an onboarding issue the moment it is opened
#'
#' An issue opened from an intake form carries the chapter's details as
#' form answers and nothing else. This rewrites it into the shape every
#' other command expects - the canonical checklist plus the
#' machine-readable block - gives it the conventional title, assigns the
#' onboarding team, and runs the checks that need no human judgement.
#'
#' For a new chapter it also drafts the Meetup group. Drafting creates
#' nothing public and a draft can be discarded, so doing it up front
#' costs nothing and leaves @rladies/meetup-pro with only the publish to
#' do. A draft that fails is reported and the rest of the intake stands.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return A data frame of steps, invisibly, as [chapter_provision()]
#'   returns.
#' @export
chapter_intake <- function(
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

  labels <- vapply(
    issue$labels %or% list(),
    function(l) l$name %or% "",
    character(1)
  )
  kind <- chapter_intake_kind(labels)
  if (is.null(kind)) {
    cli::cli_abort(c(
      "Issue #{issue_number} is not an onboarding intake form.",
      "i" = "Neither the {.val new chapter} nor the {.val chapter update} ",
      "i" = "label is on it, so there is nothing to take over."
    ))
  }

  if (!is.null(chapter_meta_parse(issue$body))) {
    cli::cli_alert_info("Issue #{issue_number} has already been taken over")
    return(invisible(provision_step("Intake", "skipped", "already done")))
  }

  details <- chapter_intake_details(issue$body)
  if (is.null(details$city) || is.null(details$country)) {
    cli::cli_abort(c(
      "Issue #{issue_number} gives no city and country.",
      "i" = "Both are required fields on the intake form."
    ))
  }

  steps <- list()

  steps[[1]] <- provision_try("Issue set up", function() {
    gh::gh(
      "PATCH /repos/{owner}/{repo}/issues/{issue_number}",
      owner = org,
      repo = onboarding_repo,
      issue_number = issue_number,
      title = chapter_intake_title(kind, details),
      body = chapter_intake_body(kind, details)
    )
    "checklist and chapter details written"
  })

  steps[[2]] <- provision_try("Onboarding team", function() {
    review_assign_onboarding(org, onboarding_repo, issue_number)
    "notified"
  })

  steps[[3]] <- provision_try("Duplicate check", function() {
    chapter_duplicate_comment(
      issue_number = issue_number,
      city = details$city,
      country = details$country,
      region = details$region,
      org = org,
      onboarding_repo = onboarding_repo
    )
    "posted"
  })

  steps[[4]] <- if (!identical(kind, "setup")) {
    provision_step("Meetup draft", "skipped", "not a new chapter")
  } else {
    provision_try("Meetup draft", function() {
      chapter_meetup_draft(issue_number, org, onboarding_repo)
      "drafted; publish it when the checks are done"
    })
  }

  report <- do.call(rbind, steps)

  announce_post_reply(
    org,
    onboarding_repo,
    issue_number,
    chapter_intake_report(report, kind, details)
  )

  invisible(report)
}

#' Render an intake run as a comment
#' @keywords internal
#' @noRd
chapter_intake_report <- function(report, kind, details) {
  icons <- provision_icons()
  lines <- glue::glue_data(
    report,
    "| {icons[status]} | {step} | {detail} |"
  )

  commands <- if (identical(kind, "setup")) {
    c(
      "`/jinx chapter-status` - where this issue has got to",
      paste(
        "`/jinx chapter-meetup-publish` - publish the drafted group",
        "(irreversible)"
      ),
      "`/jinx chapter-email` - the mailbox, after an approval comment",
      "`/jinx chapter-slack` - the organisers Slack prompt",
      paste(
        "`/jinx chapter-provision` - website entry and GitHub team;",
        "add `repo` for a presentations repo"
      )
    )
  } else {
    c(
      "`/jinx chapter-status` - where this issue has got to",
      "`/jinx chapter-provision` - website entry and GitHub team"
    )
  }

  paste0(
    "## Onboarding started for ",
    details$city,
    ", ",
    details$country,
    "\n\n",
    "| | Step | Detail |\n| --- | --- | --- |\n",
    paste(lines, collapse = "\n"),
    "\n\n",
    "Nothing public has been created. The checks in the checklist above ",
    "are still yours to make.\n\n",
    "On this issue you can run:\n\n",
    paste0("- ", commands, collapse = "\n"),
    "\n\nNo issue number needed - jinx reads the one it is commented on."
  )
}
