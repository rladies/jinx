# Open the onboarding meeting poll and post it to the onboarding issue

Part of global team onboarding: opens a "find a time" poll on samkoma so
the new member and their team can settle on an onboarding meeting slot.
The poll offers a two-week window of candidate dates starting one week
after it is created, and the poll link is posted as a comment on the
onboarding issue. The poll is created (and the comment posted) under
Jinx's identity.

## Usage

``` r
gt_schedule_onboarding_meeting(
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
)
```

## Arguments

- issue_number:

  Onboarding issue number the poll link is posted to.

- name:

  Full name of the new member (used in the poll title).

- team_name:

  Human-readable team name (used in the poll title).

- org:

  GitHub organization. Defaults to `"rladies"`.

- repo:

  Repository holding the onboarding issue. Defaults to `"global-team"`.

- start:

  First candidate date. Defaults to one week from today.

- from, to:

  Daily availability window in 24h `"HH:MM"`. Defaults to a broad UTC
  band that overlaps working hours across regions.

- slot:

  Slot length in minutes. Defaults to 30.

- tz:

  IANA timezone the poll window is painted in. Defaults to `"UTC"` since
  the global team spans timezones.

## Value

The poll URL (invisibly).
