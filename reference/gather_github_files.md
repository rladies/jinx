# Gather chunks from local files in a checked-out repo

Reads files from disk (relative to `src$root_env` env var, default
`JINX_PATH`) and runs them through
[`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md).
Required `src` fields: `repo`, `files` (each with `path`, `url`,
optional `title`).

## Usage

``` r
gather_github_files(src)
```

## Arguments

- src:

  Source spec list.

## Value

List of chunk records.
