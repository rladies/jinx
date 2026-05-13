# Welcome a first-time contributor

Checks if the PR/issue author has previous contributions to the repo. If
this is their first, posts a warm welcome message. If not first-time,
posts a shorter thank-you.

## Usage

``` r
contributor_welcome(owner, repo, number, author, is_pr = TRUE, org = "rladies")
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- number:

  Issue or PR number.

- author:

  GitHub login of the author.

- is_pr:

  Whether this is a PR (TRUE) or issue (FALSE).

- org:

  Organization name.

## Value

Comment URL or `NULL` if author is a team member (invisibly).
