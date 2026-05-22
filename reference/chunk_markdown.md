# Chunk markdown into retrieval-sized pieces

Splits a markdown document by H1/H2 sections, then packs paragraphs into
chunks of roughly `target_chars` characters. Returns a list of chunk
records with heading, title, and lastmod metadata.

## Usage

``` r
chunk_markdown(markdown, meta, target_chars = 1800, min_chars = 200)
```

## Arguments

- markdown:

  Markdown text (may include YAML frontmatter).

- meta:

  Named list with `repo`, `path`, `url`, `fallback_title`, optional
  `date`, `lastmod` (both unix seconds).

- target_chars:

  Approximate target chunk size.

- min_chars:

  Minimum chunk size; smaller chunks are dropped.

## Value

List of chunk records (one list per chunk).
