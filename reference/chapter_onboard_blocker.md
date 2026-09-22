# Which team is holding a chapter onboarding up

The owner of the first unchecked item, or `NA` when the checklist is
complete or carries no owner.

## Usage

``` r
chapter_onboard_blocker(state)
```

## Arguments

- state:

  Data frame from
  [`chapter_onboard_state()`](https://rladies.github.io/jinx/reference/chapter_onboard_state.md).

## Value

A team slug such as `"rladies/email"`, or `NA_character_`.
