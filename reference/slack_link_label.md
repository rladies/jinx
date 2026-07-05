# Neutralise Slack link-syntax metacharacters in a link label

Slack's `<url|label>` syntax offers no label escape: an unescaped `>`
terminates the link early and `<`/`|` corrupt parsing. Meetup titles are
untrusted UGC, so strip those characters before building the link.

## Usage

``` r
slack_link_label(s)
```
