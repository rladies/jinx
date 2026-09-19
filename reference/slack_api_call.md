# Generic low-level Slack API caller shared by the event/command handlers that need more than [`slack_post_message()`](https://rladies.github.io/jinx/reference/slack_post_message.md)'s single `chat.postMessage` call - DM opening, channel lookup, bookmarks, and so on. Retries on a 429 or 5xx response, honouring the `Retry-After` header up to 60s. Slack's `Retry-After` for a Tier 2 method is routinely 30-60s, so a shorter cap guarantees failure under sustained rate limiting - which a bulk pass over a workspace's channels hits readily.

Generic low-level Slack API caller shared by the event/command handlers
that need more than
[`slack_post_message()`](https://rladies.github.io/jinx/reference/slack_post_message.md)'s
single `chat.postMessage` call - DM opening, channel lookup, bookmarks,
and so on. Retries on a 429 or 5xx response, honouring the `Retry-After`
header up to 60s. Slack's `Retry-After` for a Tier 2 method is routinely
30-60s, so a shorter cap guarantees failure under sustained rate
limiting - which a bulk pass over a workspace's channels hits readily.

## Usage

``` r
slack_api_call(token, method, body = list())
```

## Arguments

- token:

  Slack bot token.

- method:

  Slack Web API method name, e.g. `"conversations.open"`.

- body:

  Named list of request parameters.

## Value

The parsed JSON response (a list).
