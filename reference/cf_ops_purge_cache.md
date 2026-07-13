# Purge specific URLs or prefixes from the Cloudflare cache

Thin wrapper over
[`cloudflarer::cf_purge_cache()`](https://rdrr.io/pkg/cloudflarer/man/cf_purge_cache.html)
that deliberately does not expose `purge_everything` — a maintainer who
genuinely needs a full-zone wipe calls
`cloudflarer::cf_purge_cache(purge_everything = TRUE)` directly. That
extra step is intentional friction on the most dangerous call this
integration can make.

## Usage

``` r
cf_ops_purge_cache(
  zone_id = Sys.getenv("CLOUDFLARE_ZONE_ID"),
  files = NULL,
  prefixes = NULL,
  token = cf_ops_token()
)
```

## Arguments

- zone_id:

  Cloudflare zone ID. Defaults to env `CLOUDFLARE_ZONE_ID`.

- files:

  Optional character vector of URLs to purge.

- prefixes:

  Optional character vector of URL prefixes to purge (without scheme),
  e.g. `"rladies.org/blog"`.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_OPS_API_TOKEN`,
  falling back to `CLOUDFLARE_API_TOKEN`.

## Value

A named list with the purge job `id`.
