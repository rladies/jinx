# Perform an httr2 request and parse its body as JSON

Perform an httr2 request and parse its body as JSON

## Usage

``` r
rag_fetch_json(req, retries = 1L)
```

## Arguments

- req:

  An [httr2::request](https://httr2.r-lib.org/reference/request.html)
  object (already configured with path, query, auth, body, headers).

- retries:

  Number of retries on transient errors.

## Value

Parsed JSON, or `NULL` on failure.
