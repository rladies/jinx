# Adversarially review a candidate challenge

Second, independent Workers AI pass that is prompted to reject the
challenge unless it is confident it is correct, unambiguous, and fairly
rated. Fails closed: any error or unparseable verdict counts as
rejection.

## Usage

``` r
r_challenge_adversarial_check(
  challenge,
  reprex_output = character(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- challenge:

  Parsed challenge from
  [`r_challenge_parse()`](https://rladies.github.io/jinx/reference/r_challenge_parse.md).

- reprex_output:

  Captured verification output from
  [`r_challenge_reprex_check()`](https://rladies.github.io/jinx/reference/r_challenge_reprex_check.md).

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

List with `ok` (logical), `verdict`, and `issues` (character vector).
