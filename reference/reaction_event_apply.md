# Apply an incoming Slack reaction event

The `reaction_added` event handler registered in `jinx_events()`:
increments the reaction-feedback tally and applies a vote to the
question the reacted-to message answered, if any.

## Usage

``` r
reaction_event_apply(team_id, event)
```

## Arguments

- team_id:

  Slack team id.

- event:

  The event's `event` payload: `reaction`, `item`.

## Value

Invisibly, `NULL`.
