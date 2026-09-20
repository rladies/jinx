# Attach Slack context fields to a parsed command

A handful of dispatched commands (`"feedback"`, `"setup-channel"`) act
on the Slack workspace/channel the command was run from, rather than
only on fields parsed from the command text itself. Owning that merge
here - mirroring how
[`event_parse()`](https://rladies.github.io/jinx/reference/event_parse.md)
owns shaping the `slack-event` payload - keeps the calling workflow YAML
a thin, untested plumbing layer instead of the place command semantics
live.

## Usage

``` r
cmd_attach_slack_context(command, team_id, channel_id, channel_name)
```

## Arguments

- command:

  Parsed command list from
  [`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md),
  or `NULL`.

- team_id:

  Slack team id the command was run from.

- channel_id:

  Slack channel id the command was run from.

- channel_name:

  Slack channel display name.

## Value

`command` with `team_id`/`channel_id`/`channel_name` added, or `NULL`
unchanged if `command` was `NULL`.
