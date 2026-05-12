# jinx

R package powering the R-Ladies GitHub organization bot. Deployed as a GitHub App (`jinx[bot]`) via GitHub Actions workflows.

## Architecture

- **R package** (not TypeScript/Probot) — R-centric org, maintainability
- **GitHub App identity** via `actions/create-github-app-token@v1`
- **`/jinx` commands** in issue comments trigger the `commands.yml` workflow
- **Scheduled workflows** handle recurring tasks (reports, sync, monitoring)
- **16 modules** across 50 R source files, 24 workflows, 25 templates

## Secrets

All workflows use `actions/create-github-app-token@v1` with these **repo secrets** (not variables):

| Secret               | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `JINX_APP_ID`        | GitHub App ID                                           |
| `JINX_PRIVATE_KEY`   | GitHub App private key (.pem)                           |
| `MEETUPR_JWT_TOKEN`  | Meetup Pro JWT token for meetupr (event-sync.yml)       |
| `MEETUPR_CLIENT_ID`  | Meetup Pro OAuth client ID for meetupr (event-sync.yml) |
| `MEETUPR_JWT_ISSUER` | Meetup Pro JWT issuer for meetupr (event-sync.yml)      |
| `AIRTABLE_API_KEY`   | Airtable API key (airtable-sync.yml)                    |

Always reference as `secrets.JINX_APP_ID`, never `vars.JINX_APP_ID`.

## Cloudflare Worker

The Slack bridge runs as a Cloudflare Worker at `https://jinx.rladies.workers.dev`.

### Endpoint conventions

Routes are grouped by service under `/<service>/<action>`:

```
/slack/command      POST   Slash commands from Slack
/slack/interact     POST   Block Kit button clicks from Slack
/slack/install      GET    Start OAuth install flow
/slack/oauth        GET    OAuth callback
/airtable/webhook   POST   Form submissions from Airtable
```

New endpoints must follow this pattern: `/<service>/<action>`. Never use flat paths like `/slack-interact` or `/airtable-webhook`.

### Token management

Slack workspace tokens are managed via OAuth, stored in Cloudflare KV (`SLACK_TOKENS` namespace) keyed by `team:<team_id>`. Use `getSlackToken(env, teamId)` to look up tokens — never hardcode workspace-specific tokens.

### Worker secrets (via `wrangler secret put`)

| Secret                    | Purpose                                        |
| ------------------------- | ---------------------------------------------- |
| `SLACK_SIGNING_SECRET`    | Verify Slack request authenticity (app-global) |
| `SLACK_CLIENT_ID`         | OAuth client ID (app-global)                   |
| `SLACK_CLIENT_SECRET`     | OAuth client secret (app-global)               |
| `AIRTABLE_WEBHOOK_SECRET` | Verify Airtable webhook requests               |
| `AIRTABLE_API_KEY`        | Airtable API access                            |

### Worker vars (in `wrangler.jsonc`)

| Var                       | Purpose                                                    |
| ------------------------- | ---------------------------------------------------------- |
| `GITHUB_REPO`             | Target repo for GitHub dispatches                          |
| `SLACK_COMMUNITY_TEAM_ID` | Community workspace team ID (for Airtable webhook routing) |
| `SLACK_ORGANIZER_TEAM_ID` | Organizer workspace team ID                                |

## Code style

- No code comments except workaround explanations
- tidyverse style, roxygen2 docs
- testthat `describe`/`it` structure
- Use `cli::` for all console output (`cli_alert_*`, `cli_abort`, `cli_h2`)
- Use `cli::format_inline()` for string interpolation instead of `glue::glue()`
- Use `sprintf()` for technical strings (GraphQL queries, regex patterns)
- Keep `paste()` only for data operations (vector collapsing, auth headers)
- Internal functions get `@keywords internal` and `@noRd`
- Hash-pipe (`#|`) chunk options in vignettes

## Key directories

```
R/                    # 50 source files, organized by module
tests/testthat/       # describe/it tests, 330+ passing
inst/config/          # YAML configs (teams, review rules, labels, events, conferences, languages)
inst/templates/       # Markdown templates with <KEY> placeholders
inst/translations/    # i18n: en, es, pt, fr
inst/schemas/         # JSON Schema validation (chapter, blog, directory, global-team, cfp, event)
inst/commands/        # help.md for /jinx help
.github/workflows/    # 24 workflows
vignettes/            # getting-started.Rmd, workflows.Rmd
```

## Modules

| Module             | Files                          | Purpose                                                                     |
| ------------------ | ------------------------------ | --------------------------------------------------------------------------- |
| Commands           | commands.R                     | `/jinx` command parsing and execution                                       |
| Team management    | global-team-\*.R               | Onboarding, offboarding, invitations                                        |
| Announcements      | announce\*.R                   | Cross-platform blog announcements (Bluesky, Mastodon, LinkedIn, newsletter) |
| Directory          | directory-\*.R                 | Directory entry validation, images, social handles                          |
| Blogs              | blog-\*.R                      | Blog entry management and link checking                                     |
| Chapters           | chapter-\*.R                   | Chapter creation, setup, health checks                                      |
| Reports            | report-\*.R                    | Weekly/monthly activity reports                                             |
| PR review          | review-\*.R                    | Auto-assign, label, checklist                                               |
| Airtable sync      | airtable-sync.R                | Bidirectional sync with Airtable                                            |
| Website            | website-automation.R           | Auto-merge pending PRs, greet contributors                                  |
| Chapter monitoring | chapter-monitor.R              | Inactivity detection and outreach                                           |
| Slack              | slack-manage.R                 | Invite automation, RSS subscriptions                                        |
| GHA dashboard      | gha-dashboard.R                | Workflow status overview                                                    |
| Contributors       | contributors.R                 | Tracking, recognition, welcome/thank                                        |
| Events             | event-meetup.R, event-manage.R | Meetup Pro integration, event sync                                          |
| Analytics          | analytics-\*.R                 | Activity trends, contributor growth, sparklines                             |
| Conferences        | conference-\*.R                | CFP tracking, speaker recommendations                                       |
| i18n               | i18n.R, i18n-validate.R        | Template translations with English fallback                                 |

## Template system

Templates in `inst/templates/` use `<KEY>` placeholders replaced by `render_template()`. The i18n module extends this with language-specific templates in `inst/translations/{lang}/` that fall back to English.

## Testing

```r
devtools::test()    # 330+ tests
devtools::check()   # must pass with 0 errors, 0 warnings
```

Run via zsh to ensure PATH includes `/opt/homebrew/bin` (pandoc, gh).

## pkgdown

`_pkgdown.yml` defines reference sections grouped by module. Build with:

```r
pkgdown::build_site()
```

Deployed to GitHub Pages via `.github/workflows/pkgdown.yml`.
