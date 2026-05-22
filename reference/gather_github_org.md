# Gather chunks from a GitHub org's teams, repo metadata, and READMEs

One chunk per team, one chunk per repo metadata block, plus chunked
README content for each live repo. Requires `GITHUB_TOKEN`. Required
`src` fields: `org`.

## Usage

``` r
gather_github_org(src)
```

## Arguments

- src:

  Source spec list.

## Value

List of chunk records.
