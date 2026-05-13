# Check blog URLs and RSS feeds for broken links

Check blog URLs and RSS feeds for broken links

## Usage

``` r
blog_check_links(blogs_path)
```

## Arguments

- blogs_path:

  Path to directory containing blog JSON files.

## Value

A data frame with columns `file`, `url`, `rss_feed`, `url_status`,
`rss_status`.
