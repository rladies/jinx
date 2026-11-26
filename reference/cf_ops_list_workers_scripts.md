# List Workers scripts deployed on the account

Thin wrapper over
[`cloudflarer::cf_list_workers_scripts()`](http://drmowinckels.io/cloudflarer/reference/cf_list_workers_scripts.md).

## Usage

``` r
cf_ops_list_workers_scripts(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  token = cf_ops_token()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

Data frame of Workers script records.
