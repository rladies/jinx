# Parse a `slack-event` dispatch payload

The Worker's `repository_dispatch` payload is already structured JSON
(unlike slash commands, which arrive as free text for
[`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md)
to split), so this is a thin validator rather than a parser: it confirms
`kind` is one of the registered `jinx_events()` entries and normalizes
the shape callers can rely on.

## Usage

``` r
event_parse(payload)
```

## Arguments

- payload:

  A list with `kind`, `team_id`, `response_url`, `event`.

## Value

A list with `kind`, `team_id`, `response_url`, `event`; `kind` is
`"unknown"` when the payload's `kind` isn't registered.
