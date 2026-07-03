# Add a community blog entry via a pull request

Builds an entry from the URL's metadata and opens a PR adding it to the
awesome-rladies-creations content directory. If an entry for the URL's
domain already exists, no PR is opened.

## Usage

``` r
blog_add_pr(
  url,
  org = "rladies",
  repo = "awesome-rladies-creations",
  content_path = "data/content",
  language = "en",
  author_name = NULL,
  base = "main"
)
```

## Arguments

- url:

  Blog URL.

- org, repo, content_path:

  Location of the blog entry JSON files.

- language:

  Language code. Defaults to `"en"`.

- author_name:

  Author name. When `NULL`, taken from page metadata.

- base:

  Base branch. Defaults to `"main"`.

## Value

A list with `status` (`"created"` or `"exists"`), `filename`, and `url`
(the PR URL when created).
