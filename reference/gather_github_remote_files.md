# Gather chunks from individually-listed files in a remote GitHub repo

Fetches the raw contents of each file via the GitHub API and runs them
through
[`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md).
Requires `GITHUB_TOKEN` in the environment. Required `src` fields:
`repo`, `files`.

## Usage

``` r
gather_github_remote_files(src)
```

## Arguments

- src:

  Source spec list.

## Value

List of chunk records.
