# Draft, verify, and propose a weekly R challenge

Top-level entry for the draft cron: builds a fully verified challenge
with
[`r_challenge_draft_build()`](https://rladies.github.io/jinx/reference/r_challenge_draft_build.md)
and, if one passes every gate, opens it as a `status: proposed` issue
via
[`r_challenge_open_issue()`](https://rladies.github.io/jinx/reference/r_challenge_open_issue.md)
for an organiser to review. Does nothing (and does not error) when no
challenge survives verification, so a scheduled run never proposes
unverified output.

## Usage

``` r
r_challenge_draft_post(
  difficulty = NULL,
  repo = "rladies/cauldron",
  max_tries = 3L,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- difficulty:

  Optional difficulty to request; `NULL` lets the model choose.

- repo:

  Target review repo as `"owner/name"`.

- max_tries:

  Maximum generate-and-verify attempts before giving up.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

Invisibly, `TRUE` if a challenge was proposed, else `FALSE`.
