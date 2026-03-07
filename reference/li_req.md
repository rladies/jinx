# Create a base LinkedIn API request

Create a base LinkedIn API request

## Usage

``` r
li_req(endpoint_version = "rest", ...)
```

## Arguments

- endpoint_version:

  API version path. Defaults to `"rest"`.

- ...:

  Passed to `li_req_auth()`.

## Value

Configured httr2 request.
