# Create a chapter JSON PR on the website repo

Generates the chapter JSON file and creates a PR to add it to the
website.

## Usage

``` r
create_chapter_json_pr(
  city,
  country,
  region = NULL,
  meetup_urlname,
  email,
  organizers,
  status = "prospective",
  social_media = list(),
  org = "rladies",
  website_repo = "rladies.github.io"
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

  Meetup group URL name.

- email:

  Chapter email address.

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

## Value

PR URL (invisibly).
