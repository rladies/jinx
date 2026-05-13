# Finalize global team onboarding for an accepted member

Adds the user to their specific team and creates a tracking issue with
the onboarding checklist.

## Usage

``` r
global_team_finalize_onboarding(
  username,
  team,
  name = username,
  org = "rladies"
)

gt_finalize_onboarding(username, team, name = username, org = "rladies")
```

## Arguments

- username:

  GitHub username.

- team:

  Team slug (e.g. "website").

- name:

  Full name.

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

The created issue URL (invisibly).
