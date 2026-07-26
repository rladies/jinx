# Resolve a channel name to a Slack `<#id|name>` mention

Falls back to plain `#name` text if the lookup fails - matches the
Worker's `channel_mention()` behaviour.

## Usage

``` r
slack_channel_mention(team_id, name, workspace, channel_index = NULL)
```

## Arguments

- team_id:

  Slack team id.

- name:

  Channel name (without `#`).

- workspace:

  `"organiser"` or `"community"`.

- channel_index:

  Optional pre-loaded index from
  [`channel_index_load()`](https://rladies.github.io/jinx/reference/channel_index_load.md),
  to avoid a redundant KV read when resolving several channel names in a
  row.

## Value

Character string mention.
