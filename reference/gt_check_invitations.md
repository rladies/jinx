# Check pending global team invitations

Lists pending invitations and triggers finalization for accepted ones.

## Usage

``` r
global_team_check_invitations(org = "rladies")
gt_check_invitations(org = "rladies")
```

## Arguments

- org:

  GitHub organization. Defaults to `"rladies"`.

## Value

Character vector of usernames that have accepted their invitation
(invisibly).
