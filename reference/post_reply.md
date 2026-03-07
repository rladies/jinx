# Post a reply comment on an issue or PR

Posts as the authenticated user (jinx\[bot\] when using a GitHub App
token).

## Usage

``` r
post_reply(owner, repo, issue_number, body)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- issue_number:

  Issue or PR number.

- body:

  Comment body (markdown).

## Value

The API response (invisibly).
