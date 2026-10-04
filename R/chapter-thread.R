#' Meetup group URLs a chapter's onboarding thread might carry
#'
#' Matches the group URL the Meetup Pro team pastes when the group is
#' live. `pro/` and `members/` paths are not group pages, and neither is
#' a bare `meetup.com`, so they are excluded rather than mistaken for a
#' urlname.
#' @keywords internal
#' @noRd
chapter_thread_meetup_pattern <- function() {
  "https?://(?:www\\.)?meetup\\.com/([a-zA-Z0-9_-]+)"
}

#' Paths under meetup.com that are never a group urlname
#' @keywords internal
#' @noRd
chapter_thread_meetup_reserved <- function() {
  c("pro", "members", "member", "cities", "topics", "find", "help", "home")
}

#' The chapter mailbox pattern
#' @keywords internal
#' @noRd
chapter_thread_email_pattern <- function() {
  "[a-zA-Z0-9._%+-]+@rladies\\.org"
}

#' Pull every Meetup group urlname out of a block of text
#' @keywords internal
#' @noRd
chapter_thread_urlnames <- function(text) {
  matches <- regmatches(
    text,
    gregexpr(chapter_thread_meetup_pattern(), text, perl = TRUE)
  )[[1]]
  if (!length(matches)) {
    return(character(0))
  }
  urlnames <- sub(
    paste0("^", chapter_thread_meetup_pattern(), "$"),
    "\\1",
    matches,
    perl = TRUE
  )
  urlnames <- urlnames[!tolower(urlnames) %in% chapter_thread_meetup_reserved()]
  unique(urlnames)
}

#' Pull every chapter mailbox out of a block of text
#' @keywords internal
#' @noRd
chapter_thread_emails <- function(text) {
  matches <- regmatches(
    text,
    gregexpr(chapter_thread_email_pattern(), text, perl = TRUE)
  )[[1]]
  unique(tolower(matches))
}

#' Whether a thread entry was written by a human
#'
#' jinx's own Meetup brief proposes a urlname before the group exists,
#' so reading the bot's comments back would have it confirm its own
#' guess as fact.
#' @keywords internal
#' @noRd
chapter_thread_is_human <- function(entry) {
  login <- entry$user$login %or% ""
  nzchar(login) && !is_bot(login)
}

#' Read an onboarding thread for the facts later steps need
#'
#' The onboarding checklist asks the email and Meetup Pro teams to post
#' the mailbox and the group URL as comments. Those comments are the
#' only record, so the facts are read back out of the conversation
#' rather than asked for again.
#'
#' Only human comments count, and the first posting of a fact wins: a
#' later comment quoting the URL back cannot displace the team that
#' announced it.
#'
#' @param issue_number Onboarding issue number.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return A list with `urlname`, `email` and `meetup_url`, each `NULL`
#'   when the thread does not carry it yet.
#' @export
chapter_thread_scan <- function(
  issue_number,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
) {
  comments <- gh::gh(
    "GET /repos/{owner}/{repo}/issues/{issue_number}/comments",
    owner = org,
    repo = onboarding_repo,
    issue_number = issue_number,
    .limit = Inf
  )

  bodies <- vapply(
    Filter(chapter_thread_is_human, comments),
    function(comment) comment$body %or% "",
    character(1)
  )

  urlnames <- unlist(lapply(bodies, chapter_thread_urlnames))
  emails <- unlist(lapply(bodies, chapter_thread_emails))

  urlname <- if (length(urlnames)) urlnames[[1]] else NULL
  list(
    urlname = urlname,
    email = if (length(emails)) emails[[1]] else NULL,
    meetup_url = if (!is.null(urlname)) {
      paste0("https://www.meetup.com/", urlname, "/")
    }
  )
}
