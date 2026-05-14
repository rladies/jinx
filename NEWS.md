# jinx (development version)

## Welcome reusable improvements

- `gh_welcome_contributor()` and `gh_greet_contributor()` gained an
  `extra_message` argument. The string is appended after the standard
  welcome and before the jinx signature, so callers can add a
  project-specific reminder (e.g. "remember to add yourself to
  `.zenodo.json`") without forking the function.
- `reusable-welcome-contributor.yml` now accepts a matching
  `extra_message` workflow input and forwards it via an environment
  variable (no string interpolation into the R source, so the input is
  safe to set to any markdown).
- The reusable also fires on `pull_request_target` opens, so callers
  that need to welcome fork-PR authors can switch their trigger
  without losing the welcome step.

## Module reorganisation

- New `gh_*` module for reusable GitHub PR/issue automation. Functions
  moved out of the contributor/website modules so they can be wired into
  any repo, not just the website:
  - `contributor_welcome()` → `gh_welcome_contributor()`
  - `contributor_thank()` → `gh_thank_contributor()`
  - `contributor_greet()` → `gh_greet_contributor()`
- `blog_post_checklist()` → `website_blog_checklist()` (it has always
  been a website-automation function).
- `chapter_get_language()` → `i18n_chapter_language()` (it has always
  lived in `R/i18n.R`).
- Internal helpers `directory_validation_row()` and
  `directory_empty_validation_df()` in `R/i18n-validate.R` renamed to
  `i18n_validation_row()` / `i18n_empty_validation_df()` (they validate
  translations, not directory entries).
- Reusable workflows updated to call the new names: `reusable-welcome-
contributor.yml`, `reusable-thank-contributor.yml`,
  `reusable-website-blog-checklist.yml`.

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
