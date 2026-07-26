# Draft a proposed Guide answer for a content-gap question

Calls Workers AI to draft a short, human-reviewable answer for a
question Jinx could not answer well. Failures are swallowed - a digest
with an undrafted gap is better than a failed scheduled run. R port of
`draft_guide_snippet()` from the deleted
`worker/src/question-digest.js`.

## Usage

``` r
question_draft_guide_snippet(
  question,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- question:

  The question Jinx could not answer well.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

Character scalar draft, or `NULL` if the model call failed or returned
nothing usable.
