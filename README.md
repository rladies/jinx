# jinx <img src="man/figures/sprites/working.svg" align="right" height="160" alt="Jinx the cat, sitting at a laptop, working" />

RLadies+ operations bot — an R package deployed via GitHub Actions
with a registered GitHub App identity (`jinx[bot]`), plus a Cloudflare
Worker that bridges Slack to that machinery.

Use Jinx to onboard organisers, generate org-wide reports, validate
directory PRs, schedule social posts, sync events, run translation
checks, and — via the Slack app — to invite new community members and
ask questions of the [RLadies+ Guide](https://guide.rladies.org/).

## Slack app

<p>
  <a href="https://jinx.rladies.workers.dev/slack/install">
    <img alt="Add to Slack"
         height="40" width="139"
         src="https://platform.slack-edge.com/img/add_to_slack.png"
         srcset="https://platform.slack-edge.com/img/add_to_slack.png 1x,
                 https://platform.slack-edge.com/img/add_to_slack@2x.png 2x" />
  </a>
</p>

Jinx is only installable in the RLadies+ organisers and community
workspaces. The full landing page — slash commands, `@Jinx` mentions,
Airtable invite approval flow, scopes, troubleshooting — lives at
[**the Slack app vignette**](https://rladies.github.io/jinx/articles/slack-app.html).

See [PRIVACY.md](PRIVACY.md) for the data-handling policy.

## What Jinx does

| Area | Highlights |
|------|------------|
| Team management | `gt_invite()`, `gt_create_offboarding()`, `gt_finalize_offboarding()`, `gt_remind_stale()` |
| Chapters | `create_chapter()`, `create_chapter_setup()`, `monitor_chapter_status()`, `report_chapter_health()` |
| Directory | `validate_directory_pr()`, `validate_entry_filename()`, `verify_social_handles()`, `optimize_image()` |
| Blog | `create_blog_entry()`, `check_blog_links()`, `auto_merge_pending()` |
| Announcements | `announce_post()` cross-posts to Bluesky, LinkedIn, Mastodon + newsletter |
| Reports | `generate_report()`, `format_analytics_markdown()`, `collect_website_analytics()` |
| Events | `list_chapter_events()`, `sync_chapter_events()`, `create_event_summary()` |
| Conferences | `add_cfp()`, `check_cfp_deadlines()`, `recommend_speaker()` |
| Contributors | `welcome_contributor()`, `list_org_contributors()`, `update_contributors_md()` |
| i18n | `validate_translations()`, `check_translation_coverage()` |
| Slack | `send_slack_invite()`, `post_slack_message()`, `welcome_slack_member()` |

`/jinx help` in Slack or any issue comment prints the full slash-command
reference. The same list lives in
[`inst/commands/help.md`](inst/commands/help.md).

## Setup

### GitHub App (the `jinx[bot]` identity)

1. Register the app at
   [`rladies/settings/apps/new`](https://github.com/organizations/rladies/settings/apps/new)
   with the name `jinx`.
2. Permissions:
   - Repository: Issues (R/W), Pull Requests (R/W), Contents (Read)
   - Organization: Members (R/W), Administration (Read)
3. Events: `issue_comment`, `issues`, `pull_request`.
4. Install on the RLadies+ org.
5. Repo variables/secrets: set `JINX_APP_ID` (variable) and
   `JINX_PRIVATE_KEY` (secret).

Detailed conventions, secrets, and workflow-by-workflow notes are in
[`.github/AGENTS.md`](.github/AGENTS.md).

### Cross-repo PR review

Other RLadies+ repos opt into Jinx's PR review by adding:

```yaml
# .github/workflows/jinx-review.yml
name: PR Review
on:
  pull_request:
    types: [opened, reopened, synchronize]
jobs:
  review:
    uses: rladies/jinx/.github/workflows/pr-review.yml@main
    secrets: inherit
```

### Cloudflare Worker (Slack bridge)

The worker at `https://jinx.rladies.workers.dev` handles the OAuth
install flow, slash commands, `@`-mention events, and the Airtable
invite approval pipeline. Worker source is in [`worker/src/`](worker/src/);
deploy via `.github/workflows/deploy-worker.yml`. Required worker
secrets and KV bindings are documented in
[`.github/AGENTS.md`](.github/AGENTS.md#cloudflare-worker).

## Development

```r
# Install dev dependencies
install.packages(c("devtools", "testthat", "httptest2", "withr"))

# Load + test the package
devtools::load_all()
devtools::test()

# Full R CMD check
devtools::check()
```

Worker:

```sh
# Validate the bundle without deploying
npx --yes wrangler@4 deploy --dry-run --outdir /tmp/worker-dist
```

Vignettes:

- [Getting started](https://rladies.github.io/jinx/articles/getting-started.html)
- [Workflows](https://rladies.github.io/jinx/articles/workflows.html)
- [Slack app](https://rladies.github.io/jinx/articles/slack-app.html)

## Architecture

Jinx is a regular R package. GitHub Actions workflows call exported
functions; the `gh` package authenticates via the App-minted
`GITHUB_TOKEN` and posts back as `jinx[bot]`.

Bot-facing workflows use the prebuilt `ghcr.io/rladies/jinx-bot:latest`
image so they boot with the current package already installed. The
image is rebuilt by `.github/workflows/build-bot-image.yml` when the
runtime files change.

```
Slack / issue comment / cron
        │
        ▼
GitHub Actions workflow
        │  (jinx[bot] App-token authed)
        ▼
jinx::parse_command() ─► jinx::execute_command()
        │
        ▼
gh::gh() API call as jinx[bot]
        │
        ▼
reply posted (Slack response_url / issue comment)
```

For the Slack path, the Cloudflare Worker sits in front of GitHub
Actions, OAuthing into each workspace, verifying Slack request
signatures, and dispatching slash commands via `repository_dispatch`.
Full diagram + endpoint reference in
[`.github/AGENTS.md`](.github/AGENTS.md#cloudflare-worker).
