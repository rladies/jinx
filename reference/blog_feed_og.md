# Read a post's Open Graph preview data

One extra request per *new* post - not per feed, and not per item - so
at a post a week this is nothing next to polling the feeds themselves.
Every failure returns empty: a post with no preview is still worth
announcing, so nothing here is allowed to abort the run.

## Usage

``` r
blog_feed_og(url)
```

## Arguments

- url:

  The post's URL.

## Value

A list with `description`, `image`, and `image_alt`, each a character
scalar that may be `""`.
