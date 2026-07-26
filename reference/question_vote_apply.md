# Apply a reaction vote to the question it answered

R port of `question_vote_apply()` from `worker/src/slack-events.js`
(deleted as part of the reaction-handling migration). Looks up the D1
row an answer message links to via the
`answer_link:{team_id}: {channel}:{ts}` KV key, and increments its
up/down count.

## Usage

``` r
question_vote_apply(
  team_id,
  item,
  reaction,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- team_id:

  Slack team id.

- item:

  Reaction event's `item` list: `type`, `channel`, `ts`.

- reaction:

  Raw reaction name.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- database_id:

  D1 database ID. Defaults to the provisioned `jinx-question-log`
  database.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

`TRUE` if a vote was applied, `FALSE` otherwise.
