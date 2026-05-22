# Dispatch a source spec to the appropriate gather function

Looks up `gather_<type>()` where `<type>` has dashes replaced by
underscores. Sources extend the indexer by defining a new
`gather_<type>(src)` function.

## Usage

``` r
gather_rag_source(src)
```

## Arguments

- src:

  Source spec list (must have `type`).

## Value

List of chunk records (with `chunk_idx` set per document).
