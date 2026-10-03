# Serve every workspace's blog channel from one poll of the feeds

The scheduled entry point. Both channels want the same posts, so the
feeds are polled once and each workspace is then filtered against its
own seen-set - at a ten-minute cadence, polling per workspace would
double the requests every contributor's blog receives for no gain.

## Usage

``` r
blog_feed_run(
  workspaces = c("community", "organiser"),
  channel = env_default("SLACK_BLOG_CHANNEL", "blogs-by-rladies"),
  dry_run = FALSE,
  seed = FALSE,
  entries = NULL,
  max_age_days = 14,
  limit = 20L,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- workspaces:

  Workspaces to announce in.

- channel:

  Channel to post to. Defaults to env `SLACK_BLOG_CHANNEL`, falling back
  to `"blogs-by-rladies"`.

- dry_run:

  When `TRUE`, log the messages and record nothing.

- seed:

  When `TRUE`, record every current feed item as announced in each
  workspace without posting. Run once at cutover so the first real run
  doesn't repeat what the Feed app already posted.

- entries:

  Curated content entries. Fetched when `NULL`.

- max_age_days:

  Only announce items published within this window.

- limit:

  Most posts to announce in one run.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

Invisibly, a named integer of posts announced per workspace.

## Details

One workspace failing does not stop the others: each is attempted, and
the error is re-raised at the end so the run still goes red.
