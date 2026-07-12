# Query the anonymous question log

Reads rows from the Cloudflare D1 `jinx-question-log` database via
[`cloudflarer::cf_d1_query()`](https://rdrr.io/pkg/cloudflarer/man/cf_d1_query.html) -
the same table `worker/src/question-log.js` writes to from inside the
Cloudflare Worker when `@Jinx` answers a question. No Slack user id,
channel, or thread timestamp is stored, so a row cannot be traced to who
asked.

## Usage

``` r
question_log_query(
  since_day = as.character(Sys.Date() - 7),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- since_day:

  Character `YYYY-MM-DD`. Only rows on or after this day are returned.
  Defaults to 7 days ago.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- database_id:

  D1 database ID. Defaults to the provisioned `jinx-question-log`
  database.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

Data frame with columns `id`, `day`, `question`, `outcome`, `top_score`,
`sources`, `up`, `down`.
