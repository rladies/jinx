# Collect contributors across multiple repos

Aggregates contributor data across all non-meetup repos in the org.

## Usage

``` r
contributor_list_org(org = "rladies", exclude_pattern = "^meetup-")
```

## Arguments

- org:

  GitHub organization.

- exclude_pattern:

  Regex to exclude repos.

## Value

Data frame with `login`, `repos`, `contributions`, `avatar_url`, and
`profile_url`. `contributions` is the sum across all repos; `repos` is
the count of distinct repos contributed to.
