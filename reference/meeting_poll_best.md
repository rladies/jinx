# Get the ranked best slots for a poll

Get the ranked best slots for a poll

## Usage

``` r
meeting_poll_best(id, edit_token = NULL, base_url = samkoma_base_url())
```

## Arguments

- id:

  Poll id.

- edit_token:

  Optional host edit token, required to read a hidden poll's responses.

- base_url:

  API base URL.

## Value

A data frame with columns `slot`, `count`, and `names`
(comma-separated), ordered best-first. The total number of respondents
is attached as the `total` attribute.
