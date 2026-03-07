# Thank a contributor when their PR is merged

Posts a thank-you message and adds the contributor to the repo's
contributor list if one exists.

## Usage

``` r
thank_contributor(owner, repo, pr_number, author, org = "rladies")
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
