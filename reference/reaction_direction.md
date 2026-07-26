# Classify a Slack reaction as an up- or down-vote

R port of `reaction_direction()` from `worker/src/question-log.js`.
Strips a skin-tone modifier suffix (e.g. `"thumbsup::skin-tone-3"`)
before matching.

## Usage

``` r
reaction_direction(reaction)
```

## Arguments

- reaction:

  Raw reaction name.

## Value

`"up"`, `"down"`, or `NULL` for a neutral reaction.
