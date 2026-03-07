# Collect contributors across multiple repos

Aggregates contributor data across all non-meetup repos in the org.

## Usage

``` r
list_org_contributors(org = "rladies", exclude_pattern = "^meetup-")
```

## Arguments

- org:

  GitHub organization.

- exclude_pattern:

  Regex to exclude repos.

## Value

Data frame with `login`, `repos`, `total_contributions`, `avatar_url`,
and `profile_url`.
