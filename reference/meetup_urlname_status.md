# Whether a Meetup urlname looks taken

Advisory only. Meetup serves its single-page app with HTTP 200 for
groups that do not exist, so the status code says nothing; the check
looks for the "Group not found" copy in the body instead. That copy can
change, so this reports `"unknown"` rather than guessing when it cannot
tell, and a human should confirm before creating the group.

## Usage

``` r
meetup_urlname_status(urlname)
```

## Arguments

- urlname:

  Meetup urlname to check.

## Value

One of `"available"`, `"taken"`, or `"unknown"`.
