# Load (and cache) a workspace's full channel name-to-id index

Callers resolving several channel names at once (e.g.
[`welcome_message_render()`](https://rladies.github.io/jinx/reference/welcome_message_render.md)'s
starter-channel list) should call this once and look names up in the
result, rather than calling
[`slack_channel_id_lookup()`](https://rladies.github.io/jinx/reference/slack_channel_id_lookup.md)
per name - each call independently checks the KV cache, so looking up N
names one-by-one means N redundant KV reads (and N cache-miss races) for
data that doesn't change between them.

## Usage

``` r
channel_index_load(
  team_id,
  workspace,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- team_id:

  Slack team id.

- workspace:

  `"organiser"` or `"community"`.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

A named list mapping channel name to channel id, or `NULL` if the
channel list couldn't be fetched.
