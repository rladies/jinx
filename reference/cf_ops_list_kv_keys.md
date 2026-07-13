# List keys in a Cloudflare KV namespace

Read-only, for interactive/console use during an incident — not wired
into a `/jinx` command, since KV namespaces on this account
(`SLACK_TOKENS`, `AIRTABLE_BASES`) hold operational secrets, and a
chat-triggered arbitrary-namespace read is a real exfiltration path.

## Usage

``` r
cf_ops_list_kv_keys(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  prefix = NULL,
  token = cf_ops_token()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- namespace_id:

  KV namespace ID.

- prefix:

  Optional key-name prefix filter.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

Data frame of key records.
