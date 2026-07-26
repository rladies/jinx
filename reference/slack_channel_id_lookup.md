# Look up a Slack channel's ID by name

Caches the workspace's full channel list in KV
(`channel_index:{team_id}`, same `SLACK_TOKENS` namespace and 1h TTL the
Worker used) to avoid a paginated `conversations.list` call on every
lookup. R port of `slack_channel_id_lookup()` from
`worker/src/slack-api.js`.

## Usage

``` r
slack_channel_id_lookup(
  team_id,
  name,
  workspace,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- team_id:

  Slack team id.

- name:

  Channel name (without `#`).

- workspace:

  `"organiser"` or `"community"`.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

The channel ID, or `NULL` if not found.
