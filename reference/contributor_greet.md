# Post a greeting on new PRs/issues from non-team members

Delegates to
[`contributor_welcome()`](https://rladies.github.io/jinx/reference/contributor_welcome.md)
for first-time detection.

## Usage

``` r
contributor_greet(owner, repo, number, author, org = "rladies")
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

- org:

  Organization name.

## Value

Comment URL or `NULL` if author is a team member (invisibly).
