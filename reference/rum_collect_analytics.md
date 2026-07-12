# Collect Cloudflare RUM (Web Analytics) traffic data

Queries the Cloudflare Web Analytics beacon data for a date range, via
[`cloudflarer::cf_rum_page_views()`](https://rdrr.io/pkg/cloudflarer/man/cf_rum_page_views.html)
and
[`cloudflarer::cf_rum_top()`](https://rdrr.io/pkg/cloudflarer/man/cf_rum_top.html).
A sibling to
[`website_collect_analytics()`](https://rladies.github.io/jinx/reference/website_collect_analytics.md)
(which queries Plausible) — Cloudflare RUM is a separate, beacon-based
data source.

## Usage

``` r
rum_collect_analytics(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  site_tag = Sys.getenv("CLOUDFLARE_RUM_SITE_TAG"),
  token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  since = Sys.Date() - 30,
  until = Sys.Date()
)
```

## Arguments

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- site_tag:

  RUM site tag, as returned by
  [`cloudflarer::cf_list_rum_sites()`](https://rdrr.io/pkg/cloudflarer/man/cf_list_rum_sites.html).
  Defaults to env `CLOUDFLARE_RUM_SITE_TAG`.

- token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- since, until:

  Date range, half-open `[since, until)`. Defaults to the last 30 days.

## Value

Named list with `site_tag`, `since`, `until`, `pageviews`, `top_pages`,
`top_sources`, and `top_countries`.
