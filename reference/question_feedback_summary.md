# Summarize reaction-feedback tallies for a Slack workspace

Aggregates the `reaction_log:{team_id}:{day}:{reaction}` KV counters
[`reaction_log_increment()`](https://rladies.github.io/jinx/reference/reaction_log_increment.md)
writes, across the last `days` days. Backs the `"feedback"` command. R
port of `slash_feedback()` from the deleted `worker/src/slash-local.js`.

## Usage

``` r
question_feedback_summary(
  team_id,
  days = 7,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- team_id:

  Slack team id. Required (aborts if missing) - a blank prefix would
  otherwise scan every key in the namespace across both workspaces
  instead of just this one's.

- days:

  Number of days to look back.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

A list with `days`, `entries` (integer count of KV entries scanned), and
`totals` (a named integer vector, reaction name to summed count, sorted
descending).
