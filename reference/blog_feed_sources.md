# Split curated entries into pollable sources and gaps

An entry is pollable when it carries an `rss_feed`, whatever its `type`

- YouTube channels and plain websites serve the same Atom/RSS XML as
  blogs do. Entries without a feed can't be polled at all, so they are
  returned separately for the run to report rather than dropped
  silently.

## Usage

``` r
blog_feed_sources(entries)
```

## Arguments

- entries:

  List of entry records from the curated content list.

## Value

A list with `sources` (a data frame with columns `title`, `site`,
`feed`, `author`, and `type`) and `feedless` (a character vector of
titles).
