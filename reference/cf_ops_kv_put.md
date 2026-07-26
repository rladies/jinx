# Write a single value to a Cloudflare KV namespace

Wraps
[`cloudflarer::cf_put_kv_value()`](https://rdrr.io/pkg/cloudflarer/man/cf_put_kv_value.html).
Unlike
[`cf_ops_list_kv_keys()`](https://rladies.github.io/jinx/reference/cf_ops_list_kv_keys.md)/
[`cf_ops_get_kv_value()`](https://rladies.github.io/jinx/reference/cf_ops_get_kv_value.md),
this is not a general-purpose "read/write any key" tool exposed to a
`/jinx` command — it's called internally by event/command handlers
against a small set of hardcoded key patterns (e.g.
`pending_link:{email}`, `channel_index:{team_id}`), the same scoping the
exfiltration concern in those two functions' docs warns about.

## Usage

``` r
cf_ops_kv_put(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  namespace_id,
  key_name,
  value,
  ttl_seconds = NULL,
  token = cf_ops_token()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- namespace_id:

  KV namespace ID.

- key_name:

  Key to write.

- value:

  Character value to store.

- ttl_seconds:

  Optional expiration TTL in seconds.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

The API response (invisibly).
