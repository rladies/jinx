# Create a global team offboarding issue

Create a global team offboarding issue

## Usage

``` r
global_team_create_offboarding(
  username,
  team,
  name = username,
  org = "rladies"
)

gt_create_offboarding(username, team, name = username, org = "rladies")
```

## Arguments

- username:

  GitHub username.

- team:

  Team slug.

- name:

  Full name. Defaults to the username.

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

The created issue URL (invisibly).
