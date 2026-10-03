# Keep the items worth announcing

Drops anything already announced and anything older than `max_age_days`

- a blog joining the curated list arrives with its whole back catalogue
  in the feed, and without the age gate its first run would announce
  years of posts at once. Items with no usable date are treated as too
  old for the same reason.

## Usage

``` r
blog_feed_new_items(
  items,
  seen = character(),
  max_age_days = 14,
  now = as.numeric(Sys.time())
)
```

## Arguments

- items:

  Data frame from
  [`blog_feed_items()`](https://rladies.github.io/jinx/reference/blog_feed_items.md).

- seen:

  Character vector of item ids already announced.

- max_age_days:

  Only announce items published within this window.

- now:

  Current time, as a unix timestamp.

## Value

A subset of `items`, oldest first.
