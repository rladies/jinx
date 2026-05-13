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
