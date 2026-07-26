# Authorize a parsed event before execution

Events are gated on the originating team being an allowed workspace, not
on actor privilege (there is no "actor" for a passive event like a
reaction or a team join - anyone triggers these). `airtable_webhook`
events have no `team_id` at all (Airtable webhooks aren't Slack-team
scoped) and are trusted by construction: the Worker already verified the
webhook's shared secret before dispatching. The other three kinds are
checked against the organiser/community team allowlist, mirroring the
Worker's own `slack_team_is_allowed()`.

## Usage

``` r
event_authorize(
  event,
  organiser_id = Sys.getenv("SLACK_ORGANIZER_TEAM_ID"),
  community_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID")
)
```

## Arguments

- event:

  Parsed event list from
  [`event_parse()`](https://rladies.github.io/jinx/reference/event_parse.md),
  or `NULL`.

- organiser_id:

  Organiser workspace team id. Defaults to env
  `SLACK_ORGANIZER_TEAM_ID`.

- community_id:

  Community workspace team id. Defaults to env
  `SLACK_COMMUNITY_TEAM_ID`.

## Value

A list with `ok` (logical) and `message` (a refusal string when `ok` is
`FALSE`, otherwise `NULL`).
