# Gather chunks from a Hugo site by crawling its sitemap

Walks the sitemap (and any nested sitemap-index), filters out
non-English language roots and configured skip patterns, fetches each
page, extracts the `<main>` or `<article>` body, converts it to
GitHub-flavoured markdown via pandoc, and runs the result through
[`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md).
Required `src` fields: `repo`, `sitemap`. Optional: `title_suffix`,
`language_roots`.

## Usage

``` r
gather_hugo_site(
  src,
  min_chars = src$min_chars %or% 200L,
  skip_path_patterns = src$skip_path_patterns %or% c("^/directory/[^/]+/?$"),
  progress_every = src$progress_every %or% 100L
)
```

## Arguments

- src:

  Source spec list.

- min_chars:

  Drop pages whose extracted markdown is shorter than this many
  characters.

- skip_path_patterns:

  Perl-compatible regex patterns; URLs whose path matches any of them
  are skipped.

- progress_every:

  Log a progress line every N URLs.

## Value

List of chunk records.
