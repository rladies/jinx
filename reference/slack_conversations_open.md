# Open a Slack direct message channel

Open a Slack direct message channel

## Usage

``` r
slack_conversations_open(team_id, user_id, workspace)
```

## Arguments

- team_id:

  Slack team id.

- user_id:

  Slack user id to DM.

- workspace:

  `"organiser"` or `"community"`.

## Value

The DM channel ID, or `NULL` on failure.
