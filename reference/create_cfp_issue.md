# Create a CFP tracking issue

Create a CFP tracking issue

## Usage

``` r
create_cfp_issue(
  conference,
  deadline,
  url,
  topics = character(0),
  org = "rladies",
  repo = "global-team"
)
```

## Arguments

- conference:

  Conference name.

- deadline:

  Submission deadline (YYYY-MM-DD).

- url:

  CFP URL.

- topics:

  Character vector of topic tags.

- org:

  GitHub organization.

- repo:

  Repository to create the issue in.

## Value

Issue URL (invisibly).
