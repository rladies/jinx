# Map a Slack team id to its workspace name

Map a Slack team id to its workspace name

## Usage

``` r
slack_workspace_for_team(
  team_id,
  organiser_id = Sys.getenv("SLACK_ORGANIZER_TEAM_ID"),
  community_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID")
)
```

## Arguments

- team_id:

  Slack team id from an event/command payload.

- organiser_id:

  Organiser workspace team id. Defaults to env
  `SLACK_ORGANIZER_TEAM_ID`.

- community_id:

  Community workspace team id. Defaults to env
  `SLACK_COMMUNITY_TEAM_ID`.

## Value

`"organiser"` or `"community"`.
