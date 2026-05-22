# RAG indexer

Jinx ships with a RAG (retrieval-augmented generation) index that lets
the Slack bot answer questions from RLadies+ content — the
organizational guide, the main website, R-package docs across the org,
the meetup archive, awesome-creations feeds, and the YouTube channel.
This article explains what the indexer does, how to add a new source to
it, and how it runs in CI.

If you only want to query the index, you don’t need to read this — that
path lives in the Cloudflare Worker. This article is for *building and
extending the index* on the R side.

## What the indexer does

The indexer runs once a week (and on demand) from a GitHub Actions
workflow. On each run it:

1.  Reads a list of sources from `inst/config/rag-sources.yml`.
2.  For each source, calls the matching `gather_<type>()` function to
    produce a list of text chunks.
3.  Embeds chunks in batches with Cloudflare Workers AI
    (`@cf/baai/bge-base-en-v1.5`).
4.  Upserts the vectors into the `rladies-content` Cloudflare Vectorize
    index.

Vectors are keyed by `sha256("{repo}|{path}|{chunk_idx}")[1:32]`.
Re-running the indexer is idempotent — same content produces the same
IDs, so existing vectors are updated in place.

## The architecture

    inst/config/rag-sources.yml
            │
            ▼
       load_rag_sources()
            │
            ▼
      rag_index_build()
            │
            ├─► gather_rag_source(src)   ── dispatched per `type` ──►  gather_<type>(src)
            │                                                                │
            │                                                                ▼
            │                                                         chunk_markdown()
            │                                                                │
            ▼                                                                ▼
      cloudflare_embed()  ◄── batch of 50 ───────────  list of chunk records
            │
            ▼
      cloudflare_vectorize_upsert()
            │
            ▼
       rladies-content (Cloudflare Vectorize)

The chunking, embedding, and upsert logic live in
[`R/rag-chunk.R`](https://github.com/rladies/jinx/blob/main/R/rag-chunk.R),
[`R/rag-embed.R`](https://github.com/rladies/jinx/blob/main/R/rag-embed.R),
and
[`R/rag-index.R`](https://github.com/rladies/jinx/blob/main/R/rag-index.R).
The dispatcher
[`gather_rag_source()`](https://rladies.github.io/jinx/reference/gather_rag_source.md)
finds `gather_<type>(src)` (dashes in `type` become underscores in the
function name).

## The shipped sources

| Type | What it indexes |
|----|----|
| `hugo-site` | A Hugo site, crawled via its sitemap (HTML → markdown). |
| `github-org` | An org’s teams, repo metadata, and READMEs. |
| `pkgdown-llms` | `llms.txt` files from every R-package pkgdown site in an org. |
| `github-files` | Local files in a checked-out repo (e.g. jinx’s own NEWS.md). |
| `github-remote-files` | Individually-listed files in any GitHub repo. |
| `events-json` | A meetup events JSON feed (drops cancelled + stale events). |
| `awesome-creations` | The `awesome-rladies-creations` packages and content feeds. |
| `youtube-channel` | Every video in a YouTube channel’s uploads playlist. |

Each source ends up in `R/rag-source-<type>.R`.

## Adding a new source

Adding a source is two files and one YAML entry.

**Step 1.** Decide on a `type` — a kebab-case identifier such as
`discourse-forum`. That maps directly to the function name
`gather_discourse_forum()`.

**Step 2.** Create `R/rag-source-discourse-forum.R` and export
(`@keywords internal` is fine) a function that takes a source spec and
returns a list of chunk records:

``` r

gather_discourse_forum <- function(src) {
  # ... fetch and process ...
  list(
    list(
      text = "the chunk text — at least 200 chars after trimming",
      heading = "thread title or section heading",
      title = "page title",
      repo = src$repo,
      path = "thread/1234",
      url = "https://forum.example.com/t/1234",
      date = 1700000000L,
      lastmod = 1700000000L,
      chunk_idx = 0L
    )
  )
}
```

Each chunk record needs these fields:

- `text` — the content to embed (≥ 200 chars after trimming).
- `heading` — the section heading within the page (may be empty).
- `title` — the page title.
- `repo` / `path` — used as part of the vector ID and metadata. The pair
  must be **stable across runs** so re-indexing updates the existing
  vector instead of orphaning it.
- `url` — what the Slack bot will link to in its answer.
- `date` / `lastmod` — unix seconds. Used to apply a staleness factor at
  query time. 0 if unknown.
- `chunk_idx` — zero-based index within the document (most sources emit
  one chunk per item and use `0L`; sources that split long documents use
  [`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md)
  and assign sequential indices).

If your source produces markdown documents, use
[`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md)
so chunk sizes stay consistent across the index:

``` r

chunks <- chunk_markdown(
  markdown_text,
  meta = list(
    repo = src$repo,
    path = "/some/path",
    url = "https://example.com/some/path",
    fallback_title = "Page title"
  )
)
for (i in seq_along(chunks)) {
  chunks[[i]]$chunk_idx <- i - 1L
}
```

**Step 3.** Add a YAML entry to `inst/config/rag-sources.yml`:

``` yaml
- type: discourse-forum
  source_type: forum
  repo: example/forum
  base_url: https://forum.example.com
```

Anything you put in the YAML is passed to your gather function as the
`src` argument. `source_type` is what shows up on the retrieved chunk’s
metadata — the indexer sets it on every chunk your function returns, so
you don’t need to set it yourself.

**Step 4.** Add tests. Pure formatting/parsing helpers go in
`tests/testthat/test-rag-sources.R`; HTTP-touching helpers should be
mocked with `local_mocked_responses()` (put
[`library(httr2)`](https://httr2.r-lib.org) at the top of the test file
so you don’t need the `httr2::` prefix — see
[`test-rag-embed.R`](https://github.com/rladies/jinx/blob/main/tests/testthat/test-rag-embed.R)
for the pattern).

That’s the whole contributor surface. You don’t have to touch the
orchestrator, the dispatcher, or the embed/upsert logic.

## Running it

The Cloudflare and GitHub credentials it needs:

| Env var | What it’s for |
|----|----|
| `CLOUDFLARE_API_TOKEN` | Embedding and Vectorize upserts (required). |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account. Auto-discovered if the token has exactly one accessible account. |
| `VECTORIZE_INDEX` | Index name. Defaults to `rladies-content`. |
| `GITHUB_TOKEN` | Required for `github-org`, `pkgdown-llms`, `github-remote-files`. |
| `YOUTUBE_API_KEY` | Required for `youtube-channel`. |
| `JINX_PATH` | Path to the jinx checkout, for `github-files` source. |

Local dry run from the jinx checkout:

``` r

Sys.setenv(CLOUDFLARE_API_TOKEN = "...", GITHUB_TOKEN = "...")
jinx::rag_index_build()
```

Pass a custom source list when iterating on a single source:

``` r

my_sources <- list(
  list(
    type = "youtube-channel",
    source_type = "youtube",
    repo = "rladies/youtube",
    channel_id = "UCDgj5-mFohWZ5irWSFMFcng"
  )
)
jinx::rag_index_build(sources = my_sources)
```

## CI

The indexer runs as the
[`bot-index-content.yml`](https://github.com/rladies/jinx/blob/main/.github/workflows/bot-index-content.yml)
workflow. It’s scheduled weekly (Sundays, 04:00 UTC) and can be
dispatched manually from the Actions tab. The workflow uses
`r-lib/actions/setup-r` and pandoc — the indexer calls
[`rmarkdown::pandoc_convert()`](https://pkgs.rstudio.com/rmarkdown/reference/pandoc_convert.html)
to turn the `<main>`/`<article>` of every crawled Hugo page into GFM
markdown.

The Cloudflare Worker reads the same Vectorize index at query time — see
[`worker/src/rag.js`](https://github.com/rladies/jinx/blob/main/worker/src/rag.js).
