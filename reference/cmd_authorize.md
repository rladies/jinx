# Authorize a parsed command before execution

Privileged commands (those with a `jinx_gated` keyword in the command
registry, i.e. anything not labelled `jinx_safe`) may only be run by
members of the global team, identified via the Airtable member
directory. Read-only commands are always allowed. The check fails
closed: an unknown actor is denied, and a directory lookup error is also
denied (with a distinct "try again" message).

## Usage

``` r
cmd_authorize(
  command,
  actor = NULL,
  source = c("github", "slack"),
  workspace = NULL,
  api_key = Sys.getenv("AIRTABLE_API_KEY")
)
```

## Arguments

- command:

  Parsed command list from
  [`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md),
  or `NULL`.

- actor:

  The requesting actor: a GitHub login when `source` is `"github"`, or a
  Slack user id when `source` is `"slack"`.

- source:

  Origin of the command, `"github"` or `"slack"`.

- workspace:

  Originating Slack workspace for `source = "slack"`: `"organiser"` or
  `"community"`. Ignored for GitHub commands.

- api_key:

  Airtable API key used for the directory lookup.

## Value

A list with `ok` (logical) and `message` (a refusal string when `ok` is
`FALSE`, otherwise `NULL`).

## Details

Slack identity is only trusted in the organisers workspace. The
community workspace is openly joinable and its user ids come from a
different Slack team, so an id from there must not authorize privileged
actions; privileged Slack commands are only honored when `workspace` is
`"organiser"`.
