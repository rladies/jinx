# Select the community public channels eligible for promotion

Keeps non-archived public channels that carry a description (Slack
"purpose"), dropping the channel we post the spotlight to and any names
in `skip`. The description is what the weekly spotlight is built from,
so a channel with an empty purpose has nothing to promote and is left
out.

## Usage

``` r
promo_eligible_channels(channels, target_channel = NULL, skip = character())
```

## Arguments

- channels:

  List of Slack channel objects, as returned by
  `slack_conversations_list()`.

- target_channel:

  Name of the channel the spotlight is posted to, excluded so it never
  promotes itself.

- skip:

  Character vector of additional channel names to exclude.

## Value

A data frame with one row per eligible channel and columns `id`, `name`,
and `description` (cleaned of link markup and URLs).
