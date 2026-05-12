# Generate a website analytics report

Collects Plausible analytics and formats as markdown.

## Usage

``` r
generate_website_report(
  site_id = Sys.getenv("PLAUSIBLE_SITE_ID"),
  api_key = Sys.getenv("PLAUSIBLE_API_KEY"),
  base_url = Sys.getenv("PLAUSIBLE_URL", "https://plausible.io"),
  period = c("30d", "7d", "month", "6mo", "12mo"),
  output_path = NULL
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

- output_path:

  Optional path to write JSON data.

## Value

Named list with `analytics` and `markdown` (invisibly).
