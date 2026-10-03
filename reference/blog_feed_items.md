# Parse an RSS or Atom document into a data frame of items

Matched on `local-name()` rather than a namespace prefix: the feeds in
the curated list are a mix of RSS 2.0, Atom, and RSS 1.0/RDF written by
half a dozen site generators, and only the element names are reliably
shared between them.

## Usage

``` r
blog_feed_items(xml, base = NULL, max_items = 25L)
```

## Arguments

- xml:

  Feed document as text.

- base:

  Feed URL, used to resolve relative item links.

- max_items:

  Keep at most this many items from the top of the feed.

## Value

A data frame with columns `id`, `title`, `link`, and `date` (a unix
timestamp, `0` when the feed gave no usable date).
