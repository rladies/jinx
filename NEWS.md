# jinx (development version)

## Module reorganisation

- Two i18n exports renamed to match the `<module>_<verb>_<object>`
  pattern:
  - `i18n_translations_validate()` → `i18n_validate_translations()`
  - `i18n_coverage_check()` → `i18n_check_coverage()`
- `cmd_execute("translate-status")` / `cmd_execute("translate-validate")`,
  the `ci-i18n-validate.yml` workflow, and the integration tests all
  updated to the new names.

## Bug fixes

- `contributor_list_org()` now returns its sum column as `contributions`
  instead of `total_contributions`, matching `contributor_list()` so the
  result can be passed directly to `contributor_format()`. This fixes a
  `vapply` error in `cmd_execute("contributors-org")`.
- `cmd_execute("website-analytics")` now returns the pre-rendered
  markdown from `website_generate_report()` instead of re-running the
  formatter on the wrapper list.
- Fixed seven scheduled/reusable workflows that called functions which
  do not exist as exports. These calls would have failed silently the
  next time the workflow ran:
  - `ops-event-sync.yml`: `events_sync_chapters` / `events_create_summary` /
    `events_publish_summary` → `event_*` (singular).
  - `reusable-pr-review.yml`: `review_pr` → `review_run`.
  - `ops-update-contributors.yml`: `contributors_update` → `contributor_update`.
    Also corrected `awesome-rladies-blogs` → `awesome-rladies-creations` in
    the default repo list.
  - `ops-airtable-sync.yml`: `sync_directory_airtable` →
    `directory_sync_airtable`; `sync_gt_airtable` → `gt_sync_airtable`.

## Tests

- Added `test-commands-integration.R`, an end-to-end test for every
  `cmd_execute()` branch that wires a producer to a formatter. Mocks
  each producer with its documented return shape so future column
  renames or wrapper changes fail loudly.
- Added `test-workflows.R`, a guard test that scans every YAML in
  `.github/workflows/` and asserts every `jinx::function()` reference
  resolves to a current export. Catches function renames and stale
  workflow code before they ship.

# jinx 0.1.0

Initial release. jinx automates organisational workflows for the RLadies+
GitHub org: chapter onboarding and health, directory validation, blog and
announcement publishing, PR review, Airtable sync, Slack, analytics,
events, CFP coordination, and i18n.

Exported functions follow a `<module>_<verb>[_<object>]` schema so they
group cleanly by autocomplete. Short prefixes are used for established
acronyms (`cmd_`, `gt_`, `li_`, `cfp_`, `gha_`, `i18n_`).

Triggered via `/jinx` issue comments (`cmd_parse()` / `cmd_execute()`) and
24 GitHub Actions workflows. Ships with a pkgdown site, Getting Started
and Workflow Reference vignettes, and starter translations for Spanish,
Portuguese, and French.
