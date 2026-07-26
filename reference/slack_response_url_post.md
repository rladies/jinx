# Reply to a Slack interaction via its `response_url`

Posts directly from R rather than relying on a GitHub Actions workflow
step to curl the reply - keeps the reply logic testable and in one
language. Slack's `response_url` accepts a message replacement for up to
30 minutes after the original interaction.

## Usage

``` r
slack_response_url_post(
  response_url,
  text = NULL,
  blocks = NULL,
  replace_original = FALSE
)
```

## Arguments

- response_url:

  The `response_url` from a Slack interaction payload.

- text:

  Fallback plain text (shown if `blocks` can't render).

- blocks:

  Block Kit blocks list, or `NULL`.

- replace_original:

  Whether to replace the original message.

## Value

The raw response body (invisibly).
