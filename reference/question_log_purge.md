# Purge question-log rows past the retention window

Deletes rows from the Cloudflare D1 `jinx-question-log` database older
than `retention_days`, honouring the 180-day retention promise in
PRIVACY.md. Formerly `question_log_purge()` in
`worker/src/question-log.js`, ported here so the retention guarantee has
a single implementation.

## Usage

``` r
question_log_purge(
  retention_days = 180,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  database_id = "4500d886-2593-44f9-9a01-d38cfa26e8dc",
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- retention_days:

  Number of days to retain rows for. Defaults to 180.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- database_id:

  D1 database ID. Defaults to the provisioned `jinx-question-log`
  database.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

Integer number of rows deleted.
