# Upsert vectors into a Cloudflare Vectorize index

Custom because
[cloudflarer](https://drmowinckels.r-universe.dev/cloudflarer) does not
wrap Vectorize v2; built on its
[`cloudflarer::cf_request()`](https://rdrr.io/pkg/cloudflarer/man/cf_request.html)
and
[`cloudflarer::cf_resp()`](https://rdrr.io/pkg/cloudflarer/man/cf_resp.html)
for consistent auth and error handling.

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

The unwrapped `result` payload from the Cloudflare response.
