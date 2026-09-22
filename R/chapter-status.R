#' Read the checklist state of a chapter onboarding issue
#'
#' Parses the task list in an onboarding issue body into one row per
#' checklist item, carrying the section it sits under and the team that
#' section says is responsible for it. Nested items inherit their
#' parent's owner.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return A data frame with columns `section`, `owner`, `item`, and
#'   `done`.
#' @export
chapter_onboard_state <- function(
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
  chapter_checklist_parse(issue$body)
}

#' Parse a checklist out of an onboarding issue body
#' @param body Issue body markdown.
#' @return A data frame with columns `section`, `owner`, `item`, `done`.
#' @keywords internal
#' @noRd
chapter_checklist_parse <- function(body) {
  lines <- strsplit(body %or% "", "\n", fixed = TRUE)[[1]]
  state <- list(section = NA_character_, owner = NA_character_)
  rows <- list()

  for (line in lines) {
    state <- chapter_checklist_context(line, state)
    item <- chapter_checklist_item(line)
    if (is.null(item)) {
      next
    }
    rows[[length(rows) + 1]] <- data.frame(
      section = state$section,
      owner = state$owner,
      item = item$item,
      done = item$done,
      stringsAsFactors = FALSE
    )
  }

  if (length(rows) == 0) {
    return(chapter_checklist_empty())
  }
  do.call(rbind, rows)
}

#' Update the running section/owner context from one line
#'
#' A heading starts a new section and clears the owner; a
#' "The @rladies/<team> team will:" line names the owner for the items
#' that follow.
#' @keywords internal
#' @noRd
chapter_checklist_context <- function(line, state) {
  if (grepl("^#{2,}\\s+", line)) {
    return(list(
      section = trimws(sub("^#+\\s+", "", line)),
      owner = NA_character_
    ))
  }
  team <- regmatches(line, regexpr("@[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", line))
  if (length(team) == 1 && grepl("team will", line, fixed = TRUE)) {
    state$owner <- sub("^@", "", team)
  }
  state
}

#' Extract a task-list item from one line, if it is one
#' @keywords internal
#' @noRd
chapter_checklist_item <- function(line) {
  match <- regmatches(
    line,
    regexec("^\\s*[-*]\\s+\\[([ xX])\\]\\s*(.*)$", line, perl = TRUE)
  )[[1]]
  if (length(match) == 0) {
    return(NULL)
  }
  list(done = tolower(match[2]) == "x", item = trimws(match[3]))
}

chapter_checklist_empty <- function() {
  data.frame(
    section = character(0),
    owner = character(0),
    item = character(0),
    done = logical(0),
    stringsAsFactors = FALSE
  )
}

#' Which team is holding a chapter onboarding up
#'
#' The owner of the first unchecked item, or `NA` when the checklist is
#' complete or carries no owner.
#'
#' @param state Data frame from [chapter_onboard_state()].
#' @return A team slug such as `"rladies/email"`, or `NA_character_`.
#' @export
chapter_onboard_blocker <- function(state) {
  pending <- state[!state$done, ]
  if (nrow(pending) == 0) {
    return(NA_character_)
  }
  pending$owner[1]
}

#' Summarise an onboarding checklist as markdown
#'
#' Reports progress per section, names the next unchecked item and who
#' owns it, and says plainly when everything is done.
#'
#' @param state Data frame from [chapter_onboard_state()].
#' @param title Chapter title to put in the heading.
#' @return Markdown body as a single string.
#' @export
chapter_onboard_summary <- function(state, title = "Chapter onboarding") {
  if (nrow(state) == 0) {
    return(glue::glue("## {title}\n\nNo checklist found on this issue.\n"))
  }

  done <- sum(state$done)
  header <- glue::glue(
    "## {title}\n\n**{done} of {nrow(state)} steps complete.**\n"
  )
  paste0(
    header,
    "\n\n",
    chapter_section_progress(state),
    "\n",
    chapter_next_step(state)
  )
}

#' Per-section progress lines
#' @keywords internal
#' @noRd
chapter_section_progress <- function(state) {
  sections <- unique(state$section)
  lines <- vapply(
    sections,
    function(section) {
      rows <- state[state$section %in% section, ]
      mark <- if (all(rows$done)) "x" else " "
      label <- if (is.na(section)) "Checklist" else section
      glue::glue("- [{mark}] **{label}** - {sum(rows$done)}/{nrow(rows)}")
    },
    character(1),
    USE.NAMES = FALSE
  )
  paste0(paste(lines, collapse = "\n"), "\n")
}

#' The "what happens next" line
#' @keywords internal
#' @noRd
chapter_next_step <- function(state) {
  pending <- state[!state$done, ]
  if (nrow(pending) == 0) {
    return(
      "\nEverything is ticked off - ready to confirm with the organizers.\n"
    )
  }
  owner <- pending$owner[1]
  who <- if (is.na(owner)) "the onboarding team" else paste0("@", owner)
  glue::glue("\nNext: {pending$item[1]} ({who}).\n")
}
