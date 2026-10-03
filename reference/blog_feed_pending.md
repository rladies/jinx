# Keep the posts one workspace still owes its channel

Keep the posts one workspace still owes its channel

## Usage

``` r
blog_feed_pending(posts, seen = character(), limit = 20L)
```

## Arguments

- posts:

  List of `item`/`source` pairs from
  [`blog_feed_collect()`](https://rladies.github.io/jinx/reference/blog_feed_collect.md).

- seen:

  Character vector of item ids already announced there.

- limit:

  Most posts to announce in one run.

## Value

The subset still to announce, oldest first.
