# Draft a fully verified weekly R challenge

Orchestrates the full generator: draft with Workers AI, parse, verify
the reference solution with reprex, render the statement as a reprex,
then adversarially review. Regenerates on any failed gate, up to
`max_tries`, and returns `NULL` if none passes, so a scheduled run never
emits unverified output.

## Usage

``` r
r_challenge_draft_build(
  difficulty = NULL,
  max_tries = 3L,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- difficulty:

  Optional difficulty to request; `NULL` lets the model choose.

- max_tries:

  Maximum generate-and-verify attempts before giving up.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

A list with `challenge`, `statement` (rendered statement reprex),
`reprex` (solution verification output), `critique`, and `attempts`, or
`NULL` if no verified challenge was produced.
