# Call a Slack Web API method

Generic low-level Slack API caller shared by the event/command handlers
that need more than
[`slack_post_message()`](https://rladies.github.io/jinx/reference/slack_post_message.md)'s
single `chat.postMessage` call - DM opening, channel lookup, bookmarks,
and so on. Retries once on a 429 or 5xx response, honouring the
`Retry-After` header (capped at 5s), mirroring
`worker/src/slack-api.js`'s `slack_api_call()`.

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
