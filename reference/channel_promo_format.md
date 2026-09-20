# Format a channel spotlight as a Slack mrkdwn message

Links the featured channel in the header and appends the invitation. The
blurb is escaped with `escape_markdown()` before it goes out: a
channel's description is user-controlled and flows through the model
into a broadcast message, so this neutralises injected links and
`<!channel>`/`<!everyone>` mass-pings while leaving `*bold*`/`_italic_`
intact.

## Usage

``` r
channel_promo_format(id, name, blurb)
```

## Arguments

- id:

  Featured channel id.

- name:

  Featured channel name (without `#`).

- blurb:

  Invitation text from
  [`promo_blurb()`](https://rladies.github.io/jinx/reference/promo_blurb.md)
  or `promo_fallback_blurb()`.

## Value

Character scalar Slack mrkdwn message.
