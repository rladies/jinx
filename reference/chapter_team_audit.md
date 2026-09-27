# Compare the chapter teams against the website chapter data

Reports rather than repairs. Renaming a team changes its URL and where
its notifications go, so which of these to act on is a human decision.

## Usage

``` r
chapter_team_audit(
  org = "rladies",
  website_repo = "rladies.github.io",
  parent_team = "chapters",
  statuses = "active"
)
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

- website_repo:

  Repository holding `data/chapters`.

- parent_team:

  Slug of the parent team.

- statuses:

  Chapter statuses expected to have a team.

## Value

A data frame with `finding`, `team`, `display`, `chapter`, and
`expected_slug`.

## Details

Each row is one of:

- `ok` - the team matches a chapter's urlname

- `slug_mismatch` - a chapter matches by city, but its urlname would
  give a different slug

- `no_chapter` - no chapter in the website data explains this team

- `missing_team` - an active chapter with a Meetup group and no team
