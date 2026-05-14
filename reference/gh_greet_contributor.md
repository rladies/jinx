# Greet a new PR author

Thin wrapper around
[`gh_welcome_contributor()`](https://rladies.github.io/jinx/reference/gh_welcome_contributor.md)
that fixes `is_pr = TRUE` for use in PR-only workflows. Reusable across
any repo.

## Usage

``` r
gh_greet_contributor(owner, repo, number, author, org = "rladies")
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- number:

  PR number.

- author:

  GitHub login of the author.

- org:

  Organization name.

## Value

Comment URL or `NULL` if author is a team member (invisibly).
