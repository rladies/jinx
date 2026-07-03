# Load the Copilot review bridge configuration

Locates the grimoire source skills and the per-repository file globs
each review gate watches. See `inst/config/copilot-review.yml`.

## Usage

``` r
load_copilot_review_config()
```

## Value

Named list with `grimoire` and `repos` entries.
