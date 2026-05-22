# Default User-Agent string used by the RAG indexer's HTTP calls

Exposed as a function (rather than a hidden package constant) so every
helper that needs a User-Agent default can list it in its signature,
e.g. `cloudflare_request(token, user_agent = rag_user_agent())`.

## Usage

``` r
rag_user_agent()
```

## Value

Character scalar.
