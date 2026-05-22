# Build a base authenticated Cloudflare API request

Returns an
[httr2::request](https://httr2.r-lib.org/reference/request.html) pointed
at the v4 API root, with the bearer token attached. Callers append path
segments per endpoint:

## Usage

``` r
cloudflare_request(
  api_token,
  user_agent = rag_user_agent(),
  base_url = "https://api.cloudflare.com/client/v4"
)
```

## Arguments

- api_token:

  Cloudflare API token.

- user_agent:

  User-Agent header to attach.

- base_url:

  Cloudflare API base URL.

## Value

[httr2::request](https://httr2.r-lib.org/reference/request.html) object.

## Details

    cloudflare_request(token) |>
      httr2::req_url_path_append("accounts", id, "ai", "run", model)
