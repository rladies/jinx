# Build a request that fetches `url` through the jinx Worker

Several curated blogs sit behind Cloudflare with Bot Fight Mode on,
which managed-challenges the Azure ranges GitHub Actions runs on - those
feeds answered every scheduled poll with a 403. A Worker's egress is
scored differently, so the same request from there succeeds.

## Usage

``` r
rag_request_proxied(
  url,
  proxy = rag_proxy_url(),
  key = Sys.getenv("JINX_WORKER_API_KEY")
)
```

## Arguments

- url:

  Target URL.

- proxy:

  Worker `/content/fetch` endpoint.

- key:

  Bearer key for the Worker's HTTP API.

## Value

[httr2::request](https://httr2.r-lib.org/reference/request.html) object.

## Details

Falls back to a direct request whenever the proxy is not configured, so
local runs and tests need no Worker.
