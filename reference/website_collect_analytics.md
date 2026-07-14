# Collect website analytics from Cloudflare Web Analytics

Queries the Cloudflare GraphQL Analytics API for visitor and pageview
metrics over a date window. The website moved to Cloudflare, so
Plausible has been removed; the Cloudflare collector is pending a token
and site tag and is **not yet implemented**. The intended return shape
matches what
[`website_format_analytics()`](https://rladies.github.io/jinx/reference/website_format_analytics.md)
consumes: `aggregate`, `timeseries`, `top_pages`, and `top_sources`.

## Usage

``` r
website_collect_analytics(
  from = NULL,
  to = NULL,
  site_tag = Sys.getenv("CLOUDFLARE_SITE_TAG"),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- from, to:

  Date window (a `Date` or `"YYYY-MM-DD"` string). When both are `NULL`,
  defaults to the last 30 days.

- site_tag:

  Cloudflare Web Analytics site tag. Defaults to
  `Sys.getenv("CLOUDFLARE_SITE_TAG")`.

- account_id:

  Cloudflare account tag. Defaults to
  `Sys.getenv("CLOUDFLARE_ACCOUNT_ID")`.

- api_token:

  Cloudflare API token with Account Analytics Read. Defaults to
  `Sys.getenv("CLOUDFLARE_API_TOKEN")`.

## Value

Named list with `aggregate`, `timeseries`, `top_pages`, and
`top_sources`.
