# Build and post the weekly channel spotlight to the community workspace

Posts one channel's spotlight to the target channel, then records the
pick in KV so next week's run features a different channel. The
round-robin state is only advanced after a successful post, so a failed
run doesn't burn a channel's turn.

## Usage

``` r
channel_promo_post(
  team_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID"),
  target_channel = Sys.getenv("SLACK_PROMO_CHANNEL", "general"),
  slack_token = slack_bot_token("community"),
  skip = promo_skip_channels(),
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- team_id:

  Community Slack team id. Defaults to env `SLACK_COMMUNITY_TEAM_ID`.

- target_channel:

  Channel the spotlight is posted to (and never promotes). Defaults to
  env `SLACK_PROMO_CHANNEL`, falling back to `"general"`.

- slack_token:

  Community bot token. Defaults to
  [`slack_bot_token()`](https://rladies.github.io/jinx/reference/slack_bot_token.md)
  for the community workspace.

- skip:

  Additional channel names to exclude. Defaults to the comma-separated
  env `SLACK_PROMO_SKIP`.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model used for drafting.

## Value

Invisibly, `TRUE` if a spotlight was posted, `FALSE` if there was
nothing eligible to promote.
