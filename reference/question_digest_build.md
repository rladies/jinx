# Build the weekly question-gap digest text

Queries the anonymous question log, ranks content gaps and downvoted
answers, drafts a proposed Guide answer for the top gaps, and formats
the lot as Slack mrkdwn. R port of `question_digest_build()` from the
deleted `worker/src/question-digest.js`.

## Usage

``` r
question_digest_build(
  days = 7,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- days:

  Number of days to cover. Defaults to 7.

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

Character scalar digest text, or `NULL` when nothing was logged.
