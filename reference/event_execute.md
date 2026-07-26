# Execute a parsed, authorized event

Unlike
[`cmd_execute()`](https://rladies.github.io/jinx/reference/cmd_execute.md),
handlers perform their own Slack/Airtable API calls directly rather than
returning a reply string for a workflow step to relay - there is no
single "response destination" for a passive event the way there is for a
command. The return value is a short status string for the GitHub
Actions run log only.

## Usage

``` r
event_execute(event)
```

## Arguments

- event:

  Parsed event list from
  [`event_parse()`](https://rladies.github.io/jinx/reference/event_parse.md).

## Value

Character string describing the outcome, for logging.
