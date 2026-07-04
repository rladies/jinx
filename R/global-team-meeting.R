#' Candidate dates for an onboarding meeting poll
#'
#' Onboarding meeting polls open on a two-week window of candidate dates
#' that starts one week after the poll is created, giving the new member
#' and the team lead time to paint their availability before the first
#' possible slot.
#'
#' @param start First candidate date. Defaults to one week from today.
#' @param weeks Number of weeks the window spans. Defaults to 2.
#' @return Character vector of consecutive ISO dates (`YYYY-MM-DD`).
#' @keywords internal
#' @noRd
gt_onboarding_meeting_days <- function(start = Sys.Date() + 7, weeks = 2) {
  format(start + seq_len(weeks * 7) - 1, "%Y-%m-%d")
}

#' Open the onboarding meeting poll and post it to the onboarding issue
#'
#' Part of global team onboarding: opens a "find a time" poll on samkoma so
#' the new member and their team can settle on an onboarding meeting slot.
#' The poll offers a two-week window of candidate dates starting one week
#' after it is created, and the poll link is posted as a comment on the
#' onboarding issue. The poll is created (and the comment posted) under
#' Jinx's identity.
#'
#' @param issue_number Onboarding issue number the poll link is posted to.
#' @param name Full name of the new member (used in the poll title).
#' @param team_name Human-readable team name (used in the poll title).
#' @param org GitHub organization. Defaults to `"rladies"`.
#' @param repo Repository holding the onboarding issue. Defaults to
#'   `"global-team"`.
#' @param start First candidate date. Defaults to one week from today.
#' @param from,to Daily availability window in 24h `"HH:MM"`. Defaults to a
#'   broad UTC band that overlaps working hours across regions.
#' @param slot Slot length in minutes. Defaults to 30.
#' @param tz IANA timezone the poll window is painted in. Defaults to
#'   `"UTC"` since the global team spans timezones.
#' @return The poll URL (invisibly).
#' @export
gt_schedule_onboarding_meeting <- function(
  issue_number,
  name,
  team_name,
  org = "rladies",
  repo = "global-team",
  start = Sys.Date() + 7,
  from = "08:00",
  to = "20:00",
  slot = 30,
  tz = "UTC"
) {
  title <- cli::format_inline(
    "RLadies+ Global Team onboarding meeting: {name} ({team_name})"
  )

  created <- meeting_poll_create(
    title = title,
    days = gt_onboarding_meeting_days(start),
    from = from,
    to = to,
    slot = slot,
    tz = tz,
    kind = "dates"
  )

  announce_post_reply(
    org,
    repo,
    issue_number,
    meeting_poll_format_created(created, title)
  )

  cli::cli_alert_success("Onboarding meeting poll: {created$url}")
  invisible(created$url)
}
