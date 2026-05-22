# Gather chunks from pkgdown llms.txt files across an org's R packages

Lists every R-language repo in the org, keeps the ones with a root
`DESCRIPTION` file, fetches their `llms.txt` from the pkgdown site at
`https://rladies.github.io/{repo}/llms.txt`, and chunks each. Requires
`GITHUB_TOKEN`. Required `src` fields: `org`.

## Usage

``` r
gather_pkgdown_llms(
  src,
  pkgdown_base_url = src$pkgdown_base_url %or% "https://rladies.github.io"
)
```

## Arguments

- src:

  Source spec list.

- pkgdown_base_url:

  Base URL for the org's pkgdown sites.

## Value

List of chunk records.
