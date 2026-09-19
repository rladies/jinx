# Apply a channel copy plan

Only rows with status `"apply"` are sent to Slack. Everything else is
returned untouched so the caller keeps a full record of what was skipped
and why.

## Usage

``` r
channel_copy_apply(
  plan,
  token,
  dry_run = TRUE,
  skip = character(),
  join = TRUE,
  include_drift = FALSE
)
```

## Arguments

- plan:

  A plan from
  [`channel_copy_plan()`](https://rladies.github.io/jinx/reference/channel_copy_plan.md).

- token:

  Slack bot token.

- dry_run:

  When `TRUE` (the default), report what would be sent without calling
  Slack.

- skip:

  Channel names to leave alone.

- join:

  Join channels the bot is not a member of first. Slack refuses
  `conversations.setTopic`, `setPurpose` and `rename` with
  `not_in_channel` otherwise.

- include_drift:

  Also apply rows whose live value has changed since the review. Off by
  default: drift means someone edited the channel after the copy was
  written, so applying overwrites the newer text with older reviewed
  text.

## Value

`plan` with `applied` and `error` columns added.
