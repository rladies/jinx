# Build and post the weekly question-gap digest to Slack

Build and post the weekly question-gap digest to Slack

## Usage

``` r
question_digest_post(
  days = 7,
  channel = Sys.getenv("SLACK_DIGEST_CHANNEL", "team-jinx"),
  slack_token = Sys.getenv("SLACK_TOKEN"),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- days:

  Number of days to cover. Defaults to 7.

- channel:

  Slack channel to post to. Defaults to env `SLACK_DIGEST_CHANNEL`,
  falling back to `"team-jinx"`.

- slack_token:

  Slack bot token. Defaults to env `SLACK_TOKEN`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- database_id:

  D1 database ID. Defaults to the provisioned `jinx-question-log`
  database.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model used for drafting.

## Value

Invisibly, `TRUE` if a digest was posted, `FALSE` if there was nothing
to report.
