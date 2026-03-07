# Post a greeting on new PRs/issues from non-team members

Delegates to
[`welcome_contributor()`](https://rladies.github.io/jinx/reference/welcome_contributor.md)
for first-time detection.

## Usage

``` r
greet_contributor(owner, repo, number, author, org = "rladies")
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
