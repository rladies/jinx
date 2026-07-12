# Generate a Cloudflare RUM analytics report

Collects Cloudflare Web Analytics data and formats it as markdown. A
sibling to
[`website_generate_report()`](https://rladies.github.io/jinx/reference/website_generate_report.md)
(Plausible-backed).

## Usage

``` r
rum_generate_report(
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  site_tag = Sys.getenv("CLOUDFLARE_RUM_SITE_TAG"),
  token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  since = Sys.Date() - 30,
  until = Sys.Date(),
  output_path = NULL
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

- output_path:

  Optional path to write JSON data.

## Value

Named list with `analytics` and `markdown` (invisibly).
