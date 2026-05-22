# Build a base authenticated GitHub API request

Returns an
[httr2::request](https://httr2.r-lib.org/reference/request.html) pointed
at the GitHub REST root with the bearer token, API version, and a
default JSON `Accept` header attached. Callers append path segments and
override `Accept` per endpoint (e.g. `application/vnd.github.raw` for
raw file contents).

## Usage

``` r
github_request(
  token,
  user_agent = rag_user_agent(),
  base_url = "https://api.github.com"
)
```

## Arguments

- token:

  GitHub bearer token.

- user_agent:

  User-Agent header to attach.

- base_url:

  GitHub REST API base URL.

## Value

[httr2::request](https://httr2.r-lib.org/reference/request.html) object.
