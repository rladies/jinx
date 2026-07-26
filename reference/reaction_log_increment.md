# Increment the daily reaction-feedback counter for a workspace

R port of the KV counter logic in `slack_event_handle_reaction()`
(`worker/src/slack-events.js`, deleted as part of the reaction-handling
migration). Backs `/jinx feedback`.

## Usage

``` r
reaction_log_increment(
  team_id,
  reaction,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- team_id:

  Slack team id.

- reaction:

  Raw reaction name.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

Invisibly, the new count for today.
