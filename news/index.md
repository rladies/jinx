# Changelog

## jinx (development version)

### Module reorganisation

- New `gh_*` module for reusable GitHub PR/issue automation. Functions
  moved out of the contributor/website modules so they can be wired into
  any repo, not just the website:
  - `contributor_welcome()` →
    [`gh_welcome_contributor()`](https://rladies.github.io/jinx/reference/gh_welcome_contributor.md)
  - `contributor_thank()` →
    [`gh_thank_contributor()`](https://rladies.github.io/jinx/reference/gh_thank_contributor.md)
  - `contributor_greet()` →
    [`gh_greet_contributor()`](https://rladies.github.io/jinx/reference/gh_greet_contributor.md)
  - `blog_post_checklist()` →
    [`gh_post_checklist()`](https://rladies.github.io/jinx/reference/gh_post_checklist.md)
    (also generalised: the message now opens with “Thank you for
    submitting a post” so it applies to blog *and* news content equally;
    the path filter on the caller workflow already covers both).
- `chapter_get_language()` →
  [`i18n_get_chapter_language()`](https://rladies.github.io/jinx/reference/i18n_get_chapter_language.md)
  (it has always lived in `R/i18n.R`, now follows the
  `<module>_<verb>_*` pattern).
- Internal helpers `directory_validation_row()` and
  `directory_empty_validation_df()` in `R/i18n-validate.R` renamed to
  `i18n_validation_row()` / `i18n_empty_validation_df()` (they validate
  translations, not directory entries).
- Reusable workflows: `reusable-website-blog-checklist.yml` →
  `reusable-post-checklist.yml`. `reusable-welcome-contributor.yml` and
  `reusable-thank-contributor.yml` updated to call the new names.

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
