# Check community blog links from the awesome-rladies-creations repo

Lists the blog entry JSON files in the content directory via the GitHub
API and checks each entry's `url` and `rss_feed` for broken links.

## Usage

``` r
blog_check_links_repo(
  org = "rladies",
  repo = "awesome-rladies-creations",
  content_path = "data/content"
)
```

## Arguments

- org, repo, content_path:

  Location of the blog entry JSON files.

## Value

A data frame with columns `file`, `url`, `rss_feed`, `url_status`,
`rss_status`.
