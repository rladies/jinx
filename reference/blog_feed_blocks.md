# Build a new post as Slack blocks

The heading, a linked bold title and the post's own description go in
one section; the preview image follows as its own block so Slack renders
it full width rather than as a thumbnail; the byline sits in a context
block, which Slack renders small and grey so it reads as attribution
rather than as part of the post.

## Usage

``` r
blog_feed_blocks(item, source, og = list())
```

## Arguments

- item:

  A one-row data frame from
  [`blog_feed_items()`](https://rladies.github.io/jinx/reference/blog_feed_items.md).

- source:

  A one-row data frame from
  [`blog_feed_sources()`](https://rladies.github.io/jinx/reference/blog_feed_sources.md).

- og:

  Preview data from
  [`blog_feed_og()`](https://rladies.github.io/jinx/reference/blog_feed_og.md).
  Omitted fields are fine.

## Value

A list of Slack Block Kit blocks.

## Details

Every piece of text here comes from a feed or a page that contributors
control, so all of it is escaped - the link markup around the title is
the only markup the message is allowed to introduce.
