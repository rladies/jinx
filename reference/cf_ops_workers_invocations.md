# Query Workers invocation/error/CPU metrics

Thin wrapper over
[`cloudflarer::cf_workers_invocations()`](https://rdrr.io/pkg/cloudflarer/man/cf_workers_invocations.html),
defaulting `script_name` to `"jinx"` (matches `wrangler.jsonc`'s worker
name) rather than requiring the caller to know it.

## Usage

``` r
cf_ops_workers_invocations(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  since = Sys.Date() - 1,
  until = Sys.Date(),
  script_name = "jinx",
  token = cf_ops_token()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- since, until:

  Date range. Defaults to the last day.

- script_name:

  Worker script name. Defaults to `"jinx"`.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

Data frame with columns `date`, `script`, `requests`, `errors`,
`subrequests`, `cpu_p50_us`, `cpu_p99_us`.
