# Check whether an Airtable base is within the configured token's scope

Caches the allowed-bases list in KV (same `AIRTABLE_BASES` namespace and
1h TTL the Worker used) rather than calling Airtable's Meta API on every
webhook. R port of `airtable_base_is_allowed()`/
`airtable_allowed_bases_get()` from the deleted
`worker/src/airtable-meta.js`.

## Usage

``` r
airtable_base_allowed(
  base_id,
  namespace_id = airtable_bases_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  api_key = Sys.getenv("AIRTABLE_API_KEY")
)
```

## Arguments

- base_id:

  Airtable base ID to check.

- namespace_id:

  KV namespace ID for `AIRTABLE_BASES`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- api_key:

  Airtable API key. Defaults to env `AIRTABLE_API_KEY`.

## Value

`TRUE` if the base is within the token's scope.
