# Plan the channel copy and rename pass for a workspace

Compares the reviewed proposals against the workspace's live state and
classifies every intended change. A row is `"unchanged"` when Slack
already holds the proposed value, `"drift"` when the live value no
longer matches what the review recorded (someone edited it since, so the
proposal may be stale), `"missing"` when the channel is not in the
workspace, and `"apply"` otherwise.

## Usage

``` r
channel_copy_plan(
  workspace = c("organiser", "community"),
  index = NULL,
  proposals = NULL,
  renames = NULL
)
```

## Arguments

- workspace:

  Either `"organiser"` or `"community"`.

- index:

  Optional pre-fetched channel index, for testing.

- proposals, renames:

  Optional proposal data frames, for testing.

## Value

A data frame of planned changes.

## Details

Renames are planned last so a rename cannot hide the channel from the
copy rows in the same pass.
