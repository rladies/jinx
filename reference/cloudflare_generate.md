# Generate chat-completion text with a Cloudflare Workers AI model

Calls the Cloudflare REST endpoint `accounts/{id}/ai/run/{model}` with a
chat-style `messages` array and returns the generated text. Sibling of
[`cloudflare_embed()`](https://rladies.github.io/jinx/reference/cloudflare_embed.md) -
same auth/retry/error-handling idiom, built on
[`cloudflarer::cf_request()`](https://rdrr.io/pkg/cloudflarer/man/cf_request.html)
and
[`cloudflarer::cf_resp()`](https://rdrr.io/pkg/cloudflarer/man/cf_resp.html)
because cloudflarer does not wrap Workers AI inference.

## Usage

``` r
cloudflare_generate(
  messages,
  account_id,
  api_token,
  model = workers_ai_chat_model(),
  max_tokens = 256
)
```

## Arguments

- messages:

  List of chat messages, each `list(role = , content = )`.

- account_id:

  Cloudflare account ID.

- api_token:

  Cloudflare API token.

- model:

  Workers AI chat/instruct model.

- max_tokens:

  Maximum tokens to generate.

## Value

Character scalar with the model's response text.
