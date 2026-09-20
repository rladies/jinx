# Draft a spotlight invitation for a channel in Jinx's voice

Calls Workers AI to write a short, warm invitation from the channel's
name and description. Failures are swallowed and return `NULL` so the
caller can fall back to a plain-description blurb rather than skip the
promotion.

## Usage

``` r
promo_blurb(
  name,
  description,
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  model = workers_ai_chat_model()
)
```

## Arguments

- name:

  Channel name (without `#`).

- description:

  Cleaned channel description.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- model:

  Workers AI chat model.

## Value

Character scalar invitation, or `NULL` if the model call failed or
returned nothing usable.
