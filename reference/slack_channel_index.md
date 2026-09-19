# Index a workspace's public channels

Shapes the paginated output of the internal `slack_conversations_list()`
helper into the frame the copy plan compares against.

## Usage

``` r
slack_channel_index(workspace = c("organiser", "community"), channels = NULL)
```

## Arguments

- workspace:

  Either `"organiser"` or `"community"`.

- channels:

  Optional pre-fetched channel list, for testing.

## Value

A data frame with `id`, `name`, `topic`, `purpose` and `is_member`.
