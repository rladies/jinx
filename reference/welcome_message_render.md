# Render a welcome DM for a newly joined Slack member

Reads the welcome config and template directly from this package's
`inst/` (no GitHub-raw fetch needed - the content already ships here).
Falls back to a hardcoded plain-text greeting if either read fails. R
port of `welcome_message_render()` from `worker/src/slack-events.js`.

## Usage

``` r
welcome_message_render(team_id, user_id, workspace, link = NULL)
```

## Arguments

- team_id:

  Slack team id.

- user_id:

  Slack user id of the new member.

- workspace:

  `"organiser"` or `"community"`.

- link:

  Optional pending chapter sign-up link from
  [`pending_link_consume()`](https://rladies.github.io/jinx/reference/pending_link_consume.md).

## Value

Character string with the rendered welcome message.
