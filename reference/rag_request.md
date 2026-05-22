# Build a plain httr2 request with the indexer's User-Agent attached

Use for "bare" URL fetches (sitemaps, Hugo pages, generic JSON feeds)
that don't go through one of the API-specific base-request helpers
(`cloudflare_request`, `github_request`, `youtube_request`).

## Usage

``` r
rag_request(url, user_agent = rag_user_agent())
```

## Arguments

- url:

  Target URL.

- user_agent:

  User-Agent header to attach.

## Value

[httr2::request](https://httr2.r-lib.org/reference/request.html) object.
