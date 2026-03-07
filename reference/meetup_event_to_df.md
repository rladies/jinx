# Convert a Meetup GraphQL event node to a data frame row

Convert a Meetup GraphQL event node to a data frame row

## Usage

``` r
meetup_event_to_df(node, group_urlname)
```

## Arguments

- node:

  List from Meetup GraphQL response.

- group_urlname:

  Group URL name used as chapter identifier.

## Value

Single-row data frame, or `NULL` if node is invalid.
