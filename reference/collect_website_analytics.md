# Collect website analytics from Plausible

Queries the Plausible Analytics API for visitor and pageview metrics.

## Usage

``` r
collect_website_analytics(
  site_id = Sys.getenv("PLAUSIBLE_SITE_ID"),
  api_key = Sys.getenv("PLAUSIBLE_API_KEY"),
  base_url = Sys.getenv("PLAUSIBLE_URL", "https://plausible.io"),
  period = c("30d", "7d", "month", "6mo", "12mo")
)
```

## Arguments

- site_id:

  Plausible site ID (domain). Defaults to
  `Sys.getenv("PLAUSIBLE_SITE_ID")`.

- api_key:

  Plausible API key. Defaults to `Sys.getenv("PLAUSIBLE_API_KEY")`.

- base_url:

  Plausible instance URL. Defaults to
  `Sys.getenv("PLAUSIBLE_URL", "https://plausible.io")`.

- period:

  Time period: `"30d"`, `"7d"`, `"month"`, `"6mo"`, `"12mo"`.

## Value

Named list with `aggregate`, `timeseries`, `top_pages`, and
`top_sources`.
