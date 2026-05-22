# Gather chunks from RLadies+ awesome-creations feeds

Reads one or more JSON feeds (packages or content) and emits one chunk
per item. Required `src` fields: `repo`, `feeds` (each with `kind` of
"package" or "content", and `url`).

## Usage

``` r
gather_awesome_creations(src, min_chars = src$min_chars %or% 60L)
```

## Arguments

- src:

  Source spec list.

- min_chars:

  Drop chunks shorter than this many characters.

## Value

List of chunk records.
