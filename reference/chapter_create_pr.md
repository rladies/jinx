# Create a chapter JSON PR on the website repo

Generates the chapter JSON entry, validates it against the bundled
schema, and opens a PR adding it to the website. A prospective chapter
has no Meetup group or chapter email yet, so both are optional and are
simply left out of the entry.

## Usage

``` r
chapter_create_pr(
  city,
  country,
  region = NULL,
  meetup_urlname = NULL,
  email = NULL,
  organizers = character(0),
  status = "prospective",
  social_media = list(),
  org = "rladies",
  website_repo = "rladies.github.io",
  team_reviewers = "leadership"
)
```

## Arguments

- city:

  Chapter city.

- country:

  Chapter country.

- region:

  State/region/province (optional).

- meetup_urlname:

  Meetup group URL name, or `NULL` when the group does not exist yet.

- email:

  Chapter email address, or `NULL` when it does not exist yet.

- organizers:

  Character vector of organizer names.

- status:

  Chapter status. Defaults to `"prospective"`.

- social_media:

  Named list of social media handles (optional).

- org:

  GitHub organization. Defaults to `"rladies"`.

- website_repo:

  Website repository name.

- team_reviewers:

  Teams to request review from. Defaults to `"leadership"`, which the
  onboarding process requires.

## Value

PR URL (invisibly).
