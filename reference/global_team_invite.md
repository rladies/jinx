# Invite a user to the RLadies+ global team

Sends an organization membership invitation and adds the user to the
global team.

## Usage

``` r
global_team_invite(username, team, name = username, org = "rladies")

gt_invite(username, team, name = username, org = "rladies")
```

## Arguments

- username:

  GitHub username (without `@`).

- team:

  Team slug (e.g. "website").

- name:

  Full name (used in issue templates).

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

Invisibly returns `NULL`. Called for its side effect of sending the
invitation and adding the user to the specified team.
