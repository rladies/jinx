# Post the Meetup setup brief on an onboarding issue

Reads the chapter from the issue's own machine-readable block, so in the
usual case only the issue number is needed.

## Usage

``` r
chapter_meetup_request(
  issue_number,
  city = NULL,
  country = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- city:

  Chapter city. Read from the issue when `NULL`.

- country:

  Chapter country. Read from the issue when `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

## Value

The rendered brief (invisibly).
