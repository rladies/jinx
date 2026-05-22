# Perform an httr2 request and return its body as text

Treats every non-2xx response as a soft failure: warns on unexpected
statuses, returns `NULL` on 4xx/5xx and on network errors. Designed so
source gatherers can skip a missing page rather than abort the whole
indexer run.

## Usage

``` r
rag_fetch_text(req, retries = 1L)
```

## Arguments

- req:

  An [httr2::request](https://httr2.r-lib.org/reference/request.html)
  object (already configured with path, query, auth, body, headers).

- retries:

  Number of retries on transient errors.

## Value

Response body as a character string, or `NULL` on failure.

## Details

Caller is responsible for attaching a User-Agent (via
[`rag_request()`](https://rladies.github.io/jinx/reference/rag_request.md)
or one of the API-specific base-request helpers).
