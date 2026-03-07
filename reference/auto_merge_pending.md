# Auto-merge PRs with pending label when date matches

Checks open PRs with "pending" label in the website repo. If a blog
post's date matches today, merges the PR.

## Usage

``` r
auto_merge_pending(org = "rladies", repo = "rladies.github.io")
```

## Arguments

- org:

  GitHub organization.

- repo:

  Repository name.

## Value

Character vector of merged PR URLs (invisibly).
