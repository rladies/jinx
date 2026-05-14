# Post a content review checklist on a PR

Posts a review checklist comment tailored for content PRs (blog posts,
news posts, or any markdown-driven content). Generic across content
kinds — the only difference between blog and news today is the path
filter the caller workflow applies.

## Usage

``` r
gh_post_checklist(owner, repo, pr_number)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  PR number.

## Value

Comment URL (invisibly).
