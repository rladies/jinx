# Request GitHub Copilot as a reviewer on a pull request

Request GitHub Copilot as a reviewer on a pull request

## Usage

``` r
copilot_request_review(
  owner,
  repo,
  pr_number,
  reviewer = copilot_reviewer_login()
)
```

## Arguments

- owner:

  Repository owner.

- repo:

  Repository name.

- pr_number:

  Pull request number.

- reviewer:

  Copilot reviewer login.

## Value

`TRUE` if the request was accepted, `FALSE` otherwise.
