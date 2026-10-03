# Announce new community posts in one workspace's blog channel

Replaces the Slack Feed app's per-blog subscriptions with one run driven
by `awesome-rladies-creations`: a blog added to the curated list is
announced without anyone touching Slack.

## Usage

``` r
blog_feed_post(
  workspace = c("community", "organiser"),
  channel = env_default("SLACK_BLOG_CHANNEL", "blogs-by-rladies"),
  dry_run = FALSE,
  posts = NULL,
  entries = NULL,
  max_age_days = 14,
  limit = 20L,
  slack_token = NULL,
  namespace_id = slack_tokens_namespace_id(),
  account_id = Sys.getenv("CLOUDFLARE_ACCOUNT_ID"),
  api_token = Sys.getenv("CLOUDFLARE_API_TOKEN")
)
```

## Arguments

- workspace:

  Which Slack workspace to post in.

- channel:

  Channel to post to. Defaults to env `SLACK_BLOG_CHANNEL`, falling back
  to `"blogs-by-rladies"`.

- dry_run:

  When `TRUE`, log the messages and record nothing.

- posts:

  Collected posts from
  [`blog_feed_collect()`](https://rladies.github.io/jinx/reference/blog_feed_collect.md).
  Collected here when `NULL`.

- entries:

  Curated content entries. Fetched when `NULL`.

- max_age_days:

  Only announce items published within this window.

- limit:

  Most posts to announce in one run.

- slack_token:

  Bot token for `workspace`. Resolved from the workspace when unset.

- namespace_id:

  KV namespace ID for `SLACK_TOKENS`.

- account_id:

  Cloudflare account ID. Defaults to env `CLOUDFLARE_ACCOUNT_ID`.

- api_token:

  Cloudflare API token. Defaults to env `CLOUDFLARE_API_TOKEN`.

## Value

Invisibly, the number of posts announced.

## Details

Announced ids are recorded in KV per workspace, and only after a
successful post - a failed run re-announces nothing and loses nothing.

Use
[`blog_feed_run()`](https://rladies.github.io/jinx/reference/blog_feed_run.md)
to serve both workspaces, which polls the feeds once for the pair rather
than once each.
