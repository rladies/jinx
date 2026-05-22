# Build the Jinx RAG index

Gathers chunks from every configured source, embeds them with Cloudflare
Workers AI, and upserts the vectors into a Vectorize index. The source
list is loaded from `inst/config/rag-sources.yml` unless `sources` is
supplied directly.

## Usage

``` r
rag_index_build(
  sources = NULL,
  account_id = NULL,
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN"),
  index_name = NULL,
  batch_size = 50L,
  model = "@cf/baai/bge-base-en-v1.5"
)
```

## Arguments

- sources:

  Optional list of source specs (see
  [`load_rag_sources()`](https://rladies.github.io/jinx/reference/load_rag_sources.md)).

- account_id:

  Cloudflare account ID. Falls back to env `CLOUDFLARE_ACCOUNT_ID`, then
  [`cloudflare_account_id()`](https://rladies.github.io/jinx/reference/cloudflare_account_id.md).

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

- index_name:

  Vectorize index. Defaults to env `VECTORIZE_INDEX` or
  `"rladies-content"`.

- batch_size:

  Number of chunks per embed/upsert call.

- model:

  Workers AI embedding model.

## Value

Invisibly: list with `chunks` (total) and `upsert` (API response).
