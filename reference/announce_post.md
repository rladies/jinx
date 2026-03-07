# Announce a blog post across multiple platforms

Reads YAML front matter from a blog post, creates an announcement
message, and posts to selected platforms.

## Usage

``` r
announce_post(
  post,
  platforms = c("bluesky", "linkedin", "mastodon"),
  newsletter = TRUE
)
```

## Arguments

- post:

  File path to the blog post (markdown with YAML front matter).

- platforms:

  Character vector of platforms to post to. Defaults to all:
  `"bluesky"`, `"linkedin"`, `"mastodon"`.

- newsletter:

  Logical, whether to also send a newsletter. Defaults to `TRUE`.
