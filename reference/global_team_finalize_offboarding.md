# Finalize global team offboarding by removing user from teams

Finalize global team offboarding by removing user from teams

## Usage

``` r
global_team_finalize_offboarding(username, team, org = "rladies")

gt_finalize_offboarding(username, team, org = "rladies")
```

## Arguments

- username:

  GitHub username.

- team:

  Team slug.

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

Invisibly returns `NULL`. Called for its side effect of removing the
user from the specified teams.
