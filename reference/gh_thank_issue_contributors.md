# Thank everyone who took part in a closed issue

Posts a thank-you when an issue is closed, crediting the person who
raised it (with a warmer message if it was their first here) plus
everyone who was assigned to it or commented on it.

## Usage

``` r
gh_thank_issue_contributors(owner, repo, number, author, completed = TRUE)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- number:

  Issue number.

- author:

  GitHub login of the person who opened the issue.

- completed:

  Whether the issue was closed as completed. An issue closed as
  `not_planned` (spam, duplicate, invalid) is still thanked, but without
  the first-timer congratulation.

## Value

Comment URL (invisibly), or `NULL` for bot authors.
