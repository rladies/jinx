# Format one new post as a Slack mrkdwn message

Titles and author names come from feeds and curated JSON that
contributors control, so both are escaped before they go into a
broadcast message - that neutralises injected links and
`<!channel>`/`<!everyone>` mass-pings while leaving the message's own
link markup intact.

## Usage

``` r
blog_feed_format(item, source)
```

## Arguments

- item:

  A one-row data frame from
  [`blog_feed_items()`](https://rladies.github.io/jinx/reference/blog_feed_items.md).

- source:

  A one-row data frame from
  [`blog_feed_sources()`](https://rladies.github.io/jinx/reference/blog_feed_sources.md).

## Value

Character scalar Slack mrkdwn message.
