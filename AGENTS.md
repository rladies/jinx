# jinx

R package powering the RLadies+ GitHub organization bot. Deployed as a
GitHub App (`jinx[bot]`) via GitHub Actions workflows.

## Architecture

- **R package** (not TypeScript/Probot) — R-centric org, maintainability
- **GitHub App identity** via `actions/create-github-app-token@v1`
- **`/jinx` commands** in issue comments trigger the `commands.yml`
  workflow
- **Scheduled workflows** handle recurring tasks (reports, sync,
  monitoring)
- **16 modules** across 50 R source files, 24 workflows, 25 templates

## Secrets

All workflows use `actions/create-github-app-token@v1` with these **repo
secrets** (not variables):

| Secret | Purpose |
|----|----|
| `JINX_APP_ID` | GitHub App ID |
| `JINX_PRIVATE_KEY` | GitHub App private key (.pem) |
| `MEETUPR_JWT_TOKEN` | Meetup Pro JWT token for meetupr (event-sync.yml) |
| `MEETUPR_CLIENT_ID` | Meetup Pro OAuth client ID for meetupr (event-sync.yml) |
| `MEETUPR_JWT_ISSUER` | Meetup Pro JWT issuer for meetupr (event-sync.yml) |
| `AIRTABLE_API_KEY` | Airtable API key (airtable-sync.yml) |
| `JINX_WORKER_URL` | Deployed worker URL (infra-slack-smoke.yml) |
| `SLACK_ORGANISER_TOKEN` | Bot token for the organisers workspace (infra-slack-smoke.yml) |
| `SLACK_HEALTHCHECK_CHANNEL` | Channel ID for healthcheck postMessage/delete (infra-slack-smoke.yml) |
| `SLACK_HEALTHCHECK_TEAM_ID` | Team ID for the smoke-test workspace (infra-slack-smoke.yml) |
| `SLACK_SIGNING_SECRET` | Slack signing secret — used to sign synthetic worker requests |

Always reference as `secrets.JINX_APP_ID`, never `vars.JINX_APP_ID`.

## Cloudflare Worker

The Slack bridge runs as a Cloudflare Worker at
`https://jinx.rladies.workers.dev`.

### Endpoint conventions

    /slack/command      POST   Slash commands from Slack
    /slack/events       POST   Events API (app_mention, etc.)
    /slack/interact     POST   Block Kit button clicks from Slack
    /slack/install      GET    Start OAuth install flow
    /slack/oauth        GET    OAuth callback
    /airtable/webhook   POST   Form submissions from Airtable

Routes follow `/<service>/<action>` — never flat paths like
`/slack-interact` or `/airtable-webhook`. Slack-side endpoints all run
through `verifySlackSignature()` in the router; `/airtable/webhook` uses
its own `x-airtable-secret` header.

### Airtable invite-approval flow

1.  Airtable webhook fires on a new invitee row → worker posts a Block
    Kit card with **Approve** / **Deny** buttons in
    `SLACK_COMMUNITY_INVITE_CHANNEL`.
2.  Click **Deny**: Airtable record marked `denied = true`, card
    replaced with a denial note. Done.
3.  Click **Approve**: card replaced in place with the manual-invite
    checklist (workspace menu → *Invite people* → paste email) and a
    single **Mark invite sent** button. *No Airtable change yet.*
4.  The organiser sends the invite via Slack workspace settings, then
    clicks **Mark invite sent** on the same card.
5.  That flip is what writes `invited = true` to Airtable, then replaces
    the card with a final “✅ Invite sent by @user — approved by
    @approver” message.

The Airtable `invited` field must mean *the invite was actually sent*,
not *approved*. Don’t flip it on Approve — wait for the **Mark invite
sent** click.

### Airtable webhook payload contract

Every `/airtable/webhook` POST must include the originating base and
table so the worker can write back to the right place. Each Airtable
automation script is responsible for passing its own IDs:

``` json
{
  "email": "person@example.com",
  "name": "Person Name",
  "chapter": "Optional chapter",
  "record_id": "recXXXXXXXXXXXXXX",
  "base_id": "appXXXXXXXXXXXXXX",
  "table_id": "tblXXXXXXXXXXXXXX"
}
```

`base_id` and `table_id` are required. Use the table ID (`tbl…`) rather
than the table name — it survives renames. `record_id`, `base_id`, and
`table_id` round-trip through the Block Kit button `value` so the
approve/deny/mark-sent handlers can PATCH the originating base.

### Airtable base allowlist

Allowed bases are discovered dynamically by calling Airtable’s Meta API
(`GET /v0/meta/bases`) with `AIRTABLE_API_KEY`. **The Airtable PAT’s
scope *is* the allowlist** — any base the token can see is accepted.
Granting the token broader access broadens what Jinx will accept; scope
the PAT to invitee-flow bases only.

The result is cached in the `AIRTABLE_BASES` KV namespace under key
`allowed_bases` with a 1-hour TTL (`worker/src/airtable-meta.js`).
Refresh on cache miss; **fail closed** if the Meta API errors during
refresh — webhook returns HTTP 503. Bust the cache early by deleting the
key from KV.

### Token management

Slack workspace tokens are managed via OAuth, stored in Cloudflare KV
(`SLACK_TOKENS` namespace) keyed by `team:<team_id>`. Use
`getSlackToken(env, teamId)` to look up tokens — never hardcode
workspace-specific tokens.

Each KV entry is JSON written by the `/slack/oauth` callback after a
successful install:

``` json
{
  "bot_token": "xoxb-...",
  "team_id": "T012345",
  "team_name": "RLadies+ Community",
  "bot_user_id": "U012345",
  "installed_at": "2026-05-12T12:34:56.789Z"
}
```

No manual seeding needed — install the app into each workspace via
`/slack/install` and the callback writes the entry. To revoke, delete
the `team:<id>` key from KV.

There is **no token fallback**. If `getSlackToken(env, teamId)` doesn’t
find a KV entry for `team:<teamId>`, it throws. Install via OAuth or it
doesn’t work.

### Workspace allowlist

Jinx is distribution-enabled in Slack so it can OAuth into RLadies+’s
two workspaces (organisers + community), **but it is not a public app**.
`handleSlackOAuthCallback` runs `isAllowedTeam(env, teamId)` against
`SLACK_ORGANIZER_TEAM_ID` and `SLACK_COMMUNITY_TEAM_ID`. Any other
team’s install attempt is rejected with HTTP 403 and never reaches KV.

To add a workspace: set its team ID as a worker secret, redeploy, run
`/slack/install` from that workspace.

### Worker secrets (via `wrangler secret put`)

| Secret | Purpose |
|----|----|
| `SLACK_SIGNING_SECRET` | Verify Slack request authenticity (app-global) |
| `SLACK_CLIENT_ID` | OAuth client ID (app-global) |
| `SLACK_CLIENT_SECRET` | OAuth client secret (app-global) |
| `SLACK_ORGANIZER_TEAM_ID` | Organiser workspace team ID — required for allowlist + RAG bot |
| `SLACK_COMMUNITY_TEAM_ID` | Community workspace team ID — required for allowlist + Airtable webhook |
| `SLACK_COMMUNITY_INVITE_CHANNEL` | Channel ID in the community workspace where invite cards are posted |
| `AIRTABLE_WEBHOOK_SECRET` | Verify Airtable webhook requests |
| `AIRTABLE_API_KEY` | Airtable PAT — scope defines the base allowlist (see below) |

### Worker vars (in `wrangler.jsonc`)

| Var           | Purpose                           |
|---------------|-----------------------------------|
| `GITHUB_REPO` | Target repo for GitHub dispatches |

## Code style

- No code comments except workaround explanations
- tidyverse style, roxygen2 docs
- testthat `describe`/`it` structure
- Use `cli::` for all console output (`cli_alert_*`, `cli_abort`,
  `cli_h2`)
- Use
  [`cli::format_inline()`](https://cli.r-lib.org/reference/format_inline.html)
  for string interpolation instead of
  [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
- Use [`sprintf()`](https://rdrr.io/r/base/sprintf.html) for technical
  strings (GraphQL queries, regex patterns)
- Keep [`paste()`](https://rdrr.io/r/base/paste.html) only for data
  operations (vector collapsing, auth headers)
- Internal functions get `@keywords internal` and `@noRd`
- Hash-pipe (`#|`) chunk options in vignettes

## Key directories

    R/                    # 50 source files, organized by module
    tests/testthat/       # describe/it tests, 330+ passing
    inst/config/          # YAML configs (teams, review rules, labels, events, conferences, languages)
    inst/templates/       # Markdown templates with <KEY> placeholders
    inst/translations/    # i18n: en, es, pt, fr
    inst/schemas/         # JSON Schema validation (chapter, blog, directory, global-team, cfp, event)
    inst/commands/        # help.md for /jinx help
    .github/workflows/    # 24 workflows
    vignettes/            # jinx.Rmd, workflows.Rmd, slack-app.Rmd, articles/architecture.Rmd, articles/privacy.Rmd

## Modules

| Module | Files | Purpose |
|----|----|----|
| Commands | commands.R | `/jinx` command parsing and execution |
| Team management | global-team-\*.R | Onboarding, offboarding, invitations |
| Announcements | announce\*.R | Cross-platform blog announcements (Bluesky, Mastodon, LinkedIn, newsletter) |
| Directory | directory-\*.R | Directory entry validation, images, social handles |
| Blogs | blog-\*.R | Blog entry management and link checking |
| Chapters | chapter-\*.R | Chapter creation, setup, health checks |
| Reports | report-\*.R | Weekly/monthly activity reports |
| PR review | review-\*.R | Auto-assign, label, checklist |
| Airtable sync | airtable-sync.R | Bidirectional sync with Airtable |
| Website | website-automation.R | Auto-merge pending PRs, greet contributors |
| Chapter monitoring | chapter-monitor.R | Inactivity detection and outreach |
| Slack | slack-manage.R | Invite automation, RSS subscriptions |
| GHA dashboard | gha-dashboard.R | Workflow status overview |
| Contributors | contributors.R | Tracking, recognition, welcome/thank |
| Events | event-meetup.R, event-manage.R | Meetup Pro integration, event sync |
| Analytics | analytics-\*.R | Activity trends, contributor growth, sparklines |
| Conferences | conference-\*.R | CFP tracking, speaker recommendations |
| i18n | i18n.R, i18n-validate.R | Template translations with English fallback |

## Template system

Templates in `inst/templates/` use `<KEY>` placeholders replaced by
`render_template()`. The i18n module extends this with language-specific
templates in `inst/translations/{lang}/` that fall back to English.

## Testing

``` r

devtools::test()    # 330+ tests
devtools::check()   # must pass with 0 errors, 0 warnings
```

Run via zsh to ensure PATH includes `/opt/homebrew/bin` (pandoc, gh).

### Worker tests

Worker JS has its own vitest suite (no R involved):

``` sh
cd worker && npm ci && npm test     # unit tests, no network
cd worker && npm run smoke           # hits real Slack + deployed worker
```

The vitest suite runs as a prereq of `infra-deploy-worker.yml`, so a
failing test blocks deploy. The smoke test runs daily and after every
successful deploy via `infra-slack-smoke.yml`, and posts to
`SLACK_HEALTHCHECK_CHANNEL` on failure.

## pkgdown

`_pkgdown.yml` defines reference sections grouped by module. Build with:

``` r

pkgdown::build_site()
```

Deployed to GitHub Pages via `.github/workflows/infra-pkgdown.yml`.
