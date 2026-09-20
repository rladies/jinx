# Ask Workers AI to draft a weekly R challenge

Low-level generator: returns the model's raw completion, which
[`r_challenge_parse()`](https://rladies.github.io/jinx/reference/r_challenge_parse.md)
turns into a structured challenge. Most callers want
[`r_challenge_draft_build()`](https://rladies.github.io/jinx/reference/r_challenge_draft_build.md),
which also verifies the result.

## Usage

``` r
r_challenge_generate(
  difficulty = NULL,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- difficulty:

  Optional difficulty to request; `NULL` lets the model choose.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

Character scalar with the model's raw response.
