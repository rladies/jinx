# Send a welcome DM to a newly joined Slack member

The `team_join` event handler registered in `jinx_events()`: consumes
any pending chapter sign-up link, opens a DM, renders the welcome
message, and posts it. R port of `slack_event_handle_team_join()` from
`worker/src/slack-events.js`.

## Usage

``` r
welcome_send(team_id, user)
```

## Arguments

- team_id:

  Slack team id.

- user:

  The event's Slack user object list: `id`, `profile$email`.

## Value

Invisibly, `NULL`.
