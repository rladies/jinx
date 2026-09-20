# Build the weekly channel-spotlight message

Lists the community workspace's public channels, keeps those with a
description, picks the next one round-robin (state stored in KV), and
drafts a Jinx-voiced invitation for it - falling back to the plain
description if the model call fails.

## Usage

``` r
channel_promo_build(
  team_id = Sys.getenv("SLACK_COMMUNITY_TEAM_ID"),
  target_channel = Sys.getenv("SLACK_PROMO_CHANNEL", "general"),
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

A list with `text` (the Slack message), `channel_id`, `channel_name`,
and `recent` (the updated round-robin state to persist), or `NULL` when
no channel is eligible.
