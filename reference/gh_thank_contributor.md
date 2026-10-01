# Thank everyone who contributed to a merged PR

Posts a thank-you message tailored to whether this is the author's first
merged PR, and credits everyone else who helped: co-authors (commit
authors and `Co-authored-by:` trailers), reviewers, and people who
commented on the PR.

## Usage

``` r
gh_thank_contributor(owner, repo, pr_number, author, org = "rladies")
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  PR number.

- author:

  GitHub login of the PR author.

- org:

  Organization name.

## Value

Comment URL (invisibly).
