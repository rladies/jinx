# Build a base YouTube Data API v3 request

Returns an
[httr2::request](https://httr2.r-lib.org/reference/request.html) with
the API base URL and `key` query parameter attached. Callers append
path + extra query params:

## Usage

``` r
youtube_request(
  api_key,
  user_agent = rag_user_agent(),
  base_url = "https://www.googleapis.com/youtube/v3"
)
```

## Arguments

- api_key:

  YouTube Data API key.

- user_agent:

  User-Agent header to attach.

- base_url:

  YouTube Data API base URL.

## Value

[httr2::request](https://httr2.r-lib.org/reference/request.html) object.

## Details

    youtube_request(key) |>
      httr2::req_url_path_append("channels") |>
      httr2::req_url_query(part = "contentDetails", id = channel_id)
