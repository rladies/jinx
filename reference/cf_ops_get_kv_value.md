# Read a single value from a Cloudflare KV namespace

Read-only, for interactive/console use during an incident — see
[`cf_ops_list_kv_keys()`](https://rladies.github.io/jinx/reference/cf_ops_list_kv_keys.md)
for why this isn't wired into a `/jinx` command.

## Usage

``` r
cf_ops_get_kv_value(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  key_name,
  token = cf_ops_token()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- namespace_id:

  KV namespace ID.

- key_name:

  Key to read.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

Character string with the stored value.
