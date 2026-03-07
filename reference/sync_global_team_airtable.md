# Sync global team data from Airtable

Fetches global team member data from Airtable and updates the website
repo data files.

## Usage

``` r
sync_global_team_airtable(
  base_id = "appZjaV7eM0Y9FsHZ",
  api_key = Sys.getenv("AIRTABLE_API_KEY"),
  org = "rladies",
  website_repo = "rladies.github.io"
)
```

## Arguments

- base_id:

  Airtable base ID for the global team.

- api_key:

  Airtable API key.

- org:

  GitHub organization.

- website_repo:

  Website repository name.

## Value

PR URL if changes found, `NULL` otherwise (invisibly).
