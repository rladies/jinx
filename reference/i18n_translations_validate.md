# Validate translations for placeholder consistency

Checks that all translated templates have the same `<KEY>` placeholders
as the English baseline.

## Usage

``` r
i18n_translations_validate(language = NULL)
```

## Arguments

- language:

  Language code to validate. If `NULL`, validates all.

## Value

Data frame with columns: template, language, status, missing_keys,
extra_keys.
