# Consume a pending chapter sign-up link for a newly joined email

Reads and deletes the KV `pending_link:{email}` record (same
`SLACK_TOKENS` namespace and key format the Airtable invite flow writes
to when marking an invite sent). R port of
`slack_pending_link_consume()` from `worker/src/slack-events.js`.

## Usage

``` r
pending_link_consume(
  email,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- email:

  Email address to look up.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

The parsed link record, or `NULL` if none was pending.
