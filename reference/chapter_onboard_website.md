# Add a prospective chapter to the website from its onboarding issue

Opens the website PR with the chapter's prospective entry, requests
review from the leadership team, links the PR on the onboarding issue,
and ticks the website step of the checklist.

## Usage

``` r
chapter_onboard_website(
  issue_number,
  city = NULL,
  country = NULL,
  region = NULL,
  organizers = NULL,
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  website_repo = "rladies.github.io"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- city:

  Chapter city. Read from the issue when `NULL`.

- country:

  Chapter country. Read from the issue when `NULL`.

- region:

  State/region/province. Read from the issue when `NULL`.

- organizers:

  Character vector of organizer names. Read from the issue when `NULL`.

- org:

  GitHub organization. Defaults to `"rladies"`.

- onboarding_repo:

  Repository holding onboarding issues.

- website_repo:

  Website repository name.

## Value

The website PR URL (invisibly).

## Details

A prospective entry deliberately carries no chapter email and no Meetup
group: neither exists at this point in onboarding, and the entry is
filled in as those steps complete.

Anything left `NULL` is read from the issue's own machine-readable
block, so in the usual case only the issue number is needed.
