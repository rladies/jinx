# Fetch a poll and its aggregated responses

Fetch a poll and its aggregated responses

## Usage

``` r
meeting_poll_get(id, edit_token = NULL, base_url = samkoma_base_url())
```

## Arguments

- id:

  Poll id.

- edit_token:

  Optional host edit token, required to read a hidden poll's responses.

- base_url:

  API base URL.

## Value

Parsed poll object as a list.
