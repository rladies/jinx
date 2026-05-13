# Translate a template with language fallback

Looks up `inst/translations/{language}/{template_name}.md` first, falls
back to `inst/templates/{template_name}.md` if the translation is
missing.

## Usage

``` r
i18n_translate_template(template_name, language = "en", variables = list())
```

## Arguments

- template_name:

  Template filename without path (e.g. "global-team-onboarding.md").

- language:

  Language code (e.g. "es", "pt", "fr"). Defaults to "en".

- variables:

  Named list of placeholder values for `render_template()`.

## Value

Rendered template as a single character string.
