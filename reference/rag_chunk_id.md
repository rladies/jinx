# Stable vector ID for a chunk

Matches the JS indexer scheme: first 32 hex chars of
`sha256("{repo}|{path}|{chunk_idx}")`.

## Usage

``` r
rag_chunk_id(repo, path, chunk_idx)
```

## Arguments

- repo:

  Source repo (e.g. `"rladies/rladiesguide"`).

- path:

  Path within the source (e.g. `/getting-started/`).

- chunk_idx:

  Zero-based chunk index within the document.

## Value

32-character hex string.
