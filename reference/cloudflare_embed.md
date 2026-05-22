# Embed texts with a Cloudflare Workers AI model

Calls the Cloudflare REST endpoint `accounts/{id}/ai/run/{model}` and
returns the embedding vectors.

## Usage

``` r
cloudflare_embed(
  texts,
  account_id,
  api_token,
  model = "@cf/baai/bge-base-en-v1.5"
)
```

## Arguments

- texts:

  Character vector of texts.

- account_id:

  Cloudflare account ID.

- api_token:

  Cloudflare API token.

- model:

  Workers AI embedding model.

## Value

List of numeric vectors, one per input text.
