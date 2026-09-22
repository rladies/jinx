# Add a prospective chapter to the website from its onboarding issue

Opens the website PR with the chapter's prospective entry, requests
review from the leadership team, links the PR on the onboarding issue,
and ticks the website step of the checklist.

## Usage

``` r
chapter_onboard_website(
  issue_number,
  city,
  country,
  region = NULL,
  organizers = character(0),
  org = "rladies",
  onboarding_repo = "new-chapters-onboarding",
  website_repo = "rladies.github.io"
)
```

## Arguments

- issue_number:

  Onboarding issue number.

- city:

  Chapter city.

- country:

  Chapter country.

- region:

  State/region/province, or `NULL`.

- organizers:

  Character vector of organizer names.

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
