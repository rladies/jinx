# Pick the next channel to spotlight, round-robin

Chooses the alphabetically-first eligible channel that has not been
featured since the cycle began, so every channel gets a turn before any
repeats. `recent` is pruned to currently-eligible ids first (channels
that were archived or lost their description drop out), and the cycle
resets once every eligible channel has been seen.

## Usage

``` r
promo_pick_channel(eligible, recent = character())
```

## Arguments

- eligible:

  Data frame from
  [`promo_eligible_channels()`](https://rladies.github.io/jinx/reference/promo_eligible_channels.md).

- recent:

  Character vector of channel ids featured earlier this cycle.

## Value

`NULL` when nothing is eligible, otherwise a list with `channel` (the
chosen single-row data frame) and `recent` (the updated vector to
persist).
