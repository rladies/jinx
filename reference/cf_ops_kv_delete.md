# Delete a single value from a Cloudflare KV namespace

Wraps
[`cloudflarer::cf_delete_kv_value()`](https://rdrr.io/pkg/cloudflarer/man/cf_delete_kv_value.html).
See
[`cf_ops_kv_put()`](https://rladies.github.io/jinx/reference/cf_ops_kv_put.md)
for why this is narrowly scoped rather than a general-purpose tool.

## Usage

``` r
cf_ops_kv_delete(
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

  Key to delete.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

The API response (invisibly).
