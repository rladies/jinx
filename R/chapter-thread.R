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

#' Meetup urlnames in the thread that are not this chapter's
#'
#' A urlname has to begin with the chapter's own derived one. Threads
#' carry links to other chapters' groups - a mentor posting one as an
#' example is the ordinary case - and adopting one of those would name
#' the GitHub team and the presentations repository after the wrong
#' chapter and upload this chapter's logo over that group's photo.
#'
#' Matched on the prefix rather than exactly, because a group the
#' Meetup Pro team made by hand may carry a suffix
#' (`rladies-oslo-norway`). A wrong guess is reported as waiting, which
#' costs a comment; a wrong match writes to another chapter's group.
#'
#' @param urlnames Urlnames found in the thread.
#' @param city Chapter city.
#' @return A list with `mine` and `theirs`, both character vectors.
#' @keywords internal
#' @noRd
chapter_thread_partition <- function(urlnames, city) {
  expected <- tolower(chapter_meetup_urlname(city))
  mine <- startsWith(tolower(urlnames), expected)
  list(mine = urlnames[mine], theirs = urlnames[!mine])
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
#' announced it. Both facts must also belong to this chapter - the
#' thread is a conversation, and other chapters' groups and addresses
#' get mentioned in it.
#'
#' @param issue_number Onboarding issue number.
#' @param city Chapter city, used to recognise this chapter's own
#'   Meetup group and mailbox among any others mentioned.
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param onboarding_repo Repository holding onboarding issues.
#' @return A list with `urlname`, `email` and `meetup_url`, each `NULL`
#'   when the thread does not carry it yet, and `other_urlnames`, the
#'   groups mentioned that belong to other chapters.
#' @export
chapter_thread_scan <- function(
  issue_number,
  city,
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

  urlnames <- unlist(lapply(bodies, chapter_thread_urlnames)) %||% character()
  emails <- unlist(lapply(bodies, chapter_thread_emails)) %||% character()

  groups <- chapter_thread_partition(urlnames, city)
  # The mailbox is <city>@rladies.org, so an address for the onboarding
  # team or another chapter - both of which get mentioned in a thread -
  # is not this chapter's and must not be reported as it.
  mine <- emails[emails == tolower(chapter_mailbox_address(city))]

  urlname <- if (length(groups$mine)) groups$mine[[1]] else NULL
  list(
    urlname = urlname,
    email = if (length(mine)) mine[[1]] else NULL,
    meetup_url = if (!is.null(urlname)) {
      paste0("https://www.meetup.com/", urlname, "/")
    },
    other_urlnames = groups$theirs
  )
}

#' The mailbox address a chapter's city gives it
#'
#' @param city Chapter city.
#' @return The address as a character scalar.
#' @keywords internal
#' @noRd
chapter_mailbox_address <- function(city) {
  paste0(chapter_slug(city), "@rladies.org")
}
