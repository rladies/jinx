# Changelog

## jinx (development version)

### Module reorganisation

- Two i18n exports renamed to match the `<module>_<verb>_<object>`
  pattern:
  - `i18n_translations_validate()` →
    [`i18n_validate_translations()`](https://rladies.github.io/jinx/reference/i18n_validate_translations.md)
  - `i18n_coverage_check()` →
    [`i18n_check_coverage()`](https://rladies.github.io/jinx/reference/i18n_check_coverage.md)
- `cmd_execute("translate-status")` /
  `cmd_execute("translate-validate")`, the `ci-i18n-validate.yml`
  workflow, and the integration tests all updated to the new names.

### Bug fixes

- [`contributor_list_org()`](https://rladies.github.io/jinx/reference/contributor_list_org.md)
  now returns its sum column as `contributions` instead of
  `total_contributions`, matching
  [`contributor_list()`](https://rladies.github.io/jinx/reference/contributor_list.md)
  so the result can be passed directly to
  [`contributor_format()`](https://rladies.github.io/jinx/reference/contributor_format.md).
  This fixes a `vapply` error in `cmd_execute("contributors-org")`.
- `cmd_execute("website-analytics")` now returns the pre-rendered
  markdown from
  [`website_generate_report()`](https://rladies.github.io/jinx/reference/website_generate_report.md)
  instead of re-running the formatter on the wrapper list.

### Tests

- Added `test-commands-integration.R`, an end-to-end test for every
  [`cmd_execute()`](https://rladies.github.io/jinx/reference/cmd_execute.md)
  branch that wires a producer to a formatter. Mocks each producer with
  its documented return shape so future column renames or wrapper
  changes fail loudly.

## jinx 0.1.0

Initial release. jinx automates organisational workflows for the
RLadies+ GitHub org: chapter onboarding and health, directory
validation, blog and announcement publishing, PR review, Airtable sync,
Slack, analytics, events, CFP coordination, and i18n.

Exported functions follow a `<module>_<verb>[_<object>]` schema so they
group cleanly by autocomplete. Short prefixes are used for established
acronyms (`cmd_`, `gt_`, `li_`, `cfp_`, `gha_`, `i18n_`).

Triggered via `/jinx` issue comments
([`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md)
/
[`cmd_execute()`](https://rladies.github.io/jinx/reference/cmd_execute.md))
and 24 GitHub Actions workflows. Ships with a pkgdown site, Getting
Started and Workflow Reference vignettes, and starter translations for
Spanish, Portuguese, and French.
