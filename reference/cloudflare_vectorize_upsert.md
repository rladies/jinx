# Upsert vectors into a Cloudflare Vectorize index

Upsert vectors into a Cloudflare Vectorize index

## Usage

``` r
cloudflare_vectorize_upsert(vectors, account_id, api_token, index_name)
```

## Arguments

- vectors:

  List of vector records, each with `id`, `values`, `metadata`.

- account_id:

  Cloudflare account ID.

- api_token:

  Cloudflare API token.

- index_name:

  Vectorize index name.

## Value

Parsed JSON response body.
