# Default starter channels for the RLadies+ Slack welcome

Channel name and short description shown to new members so they have
somewhere obvious to head first. The list starts with the channels
shared by both workspaces (see
[`common_welcome_channels()`](https://rladies.github.io/jinx/reference/common_welcome_channels.md))
and then adds workspace-specific extras. Override by passing your own
list to
[`welcome_slack_member()`](https://rladies.github.io/jinx/reference/welcome_slack_member.md).

## Usage

``` r
default_welcome_channels(workspace = c("community", "organisers"))
```

## Arguments

- workspace:

  One of `"community"` or `"organisers"`.

## Value

A list of named character vectors with `name` and `desc`.
