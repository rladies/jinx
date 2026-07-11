# Embed texts with a Cloudflare Workers AI model

Calls the Cloudflare REST endpoint `accounts/{id}/ai/run/{model}` and
returns the embedding vectors. Custom because
[cloudflarer](https://drmowinckels.r-universe.dev/cloudflarer) does not
wrap Workers AI inference; built on its
[`cloudflarer::cf_request()`](https://rdrr.io/pkg/cloudflarer/man/cf_request.html)
and
[`cloudflarer::cf_resp()`](https://rdrr.io/pkg/cloudflarer/man/cf_resp.html)
for consistent auth and error handling.

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
