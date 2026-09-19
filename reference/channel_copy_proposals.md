# Read the reviewed channel copy proposals

Read the reviewed channel copy proposals

## Usage

``` r
channel_copy_proposals(workspace = c("organiser", "community"), path = NULL)
```

## Arguments

- workspace:

  Either `"organiser"` or `"community"`.

- path:

  Optional path to the proposals CSV, for testing.

## Value

A data frame of proposals for that workspace, excluding channels that do
not exist yet.
