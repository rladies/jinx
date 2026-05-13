# jinx ![Jinx the cat, sitting at a laptop, working](reference/figures/sprites/working.svg)

RLadies+ operations bot — an R package deployed via GitHub Actions with
a registered GitHub App identity (`jinx[bot]`), plus a Cloudflare Worker
that bridges Slack to that machinery.

Use Jinx to onboard organisers, generate org-wide reports, validate
directory PRs, schedule social posts, sync events, run translation
checks, and — via the Slack app — to invite new community members and
ask questions of the [RLadies+ Guide](https://guide.rladies.org/).

## Slack app

[![Add to
Slack](https://platform.slack-edge.com/img/add_to_slack.png)](https://jinx.rladies.workers.dev/slack/install)

Jinx is only installable in the RLadies+ organisers and community
workspaces. The full landing page — slash commands, `@Jinx` mentions,
Airtable invite approval flow, scopes, troubleshooting — lives at [**the
Slack app
vignette**](https://rladies.github.io/jinx/articles/slack-app.html).

See [PRIVACY.md](https://rladies.github.io/jinx/PRIVACY.md) for the
data-handling policy.

## What Jinx does

| Area | Highlights |
|----|----|
| Team management | [`gt_invite()`](https://rladies.github.io/jinx/reference/gt_invite.md), [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/gt_create_offboarding.md), [`gt_finalize_offboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_offboarding.md), [`gt_remind_stale()`](https://rladies.github.io/jinx/reference/gt_remind_stale.md) |
| Chapters | [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md), [`chapter_create_setup()`](https://rladies.github.io/jinx/reference/create_chapter_setup.md), [`monitor_chapter_status()`](https://rladies.github.io/jinx/reference/monitor_chapter_status.md), [`chapter_report_health()`](https://rladies.github.io/jinx/reference/report_chapter_health.md) |
| Directory | [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md), [`validate_entry_filename()`](https://rladies.github.io/jinx/reference/validate_entry_filename.md), [`verify_social_handles()`](https://rladies.github.io/jinx/reference/verify_social_handles.md), [`optimize_image()`](https://rladies.github.io/jinx/reference/optimize_image.md) |
| Blog | [`blog_create_entry()`](https://rladies.github.io/jinx/reference/create_blog_entry.md), [`blog_check_links()`](https://rladies.github.io/jinx/reference/check_blog_links.md), [`website_merge_pending()`](https://rladies.github.io/jinx/reference/auto_merge_pending.md) |
| Announcements | [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md) cross-posts to Bluesky, LinkedIn, Mastodon + newsletter |
| Reports | [`report_generate()`](https://rladies.github.io/jinx/reference/generate_report.md), [`format_analytics_markdown()`](https://rladies.github.io/jinx/reference/format_analytics_markdown.md), [`collect_website_analytics()`](https://rladies.github.io/jinx/reference/collect_website_analytics.md) |
| Events | [`events_list_chapter()`](https://rladies.github.io/jinx/reference/list_chapter_events.md), [`events_sync_chapters()`](https://rladies.github.io/jinx/reference/sync_chapter_events.md), [`events_create_summary()`](https://rladies.github.io/jinx/reference/create_event_summary.md) |
| Conferences | `add_cfp()`, [`cfp_check_deadlines()`](https://rladies.github.io/jinx/reference/check_cfp_deadlines.md), [`cfp_recommend_speaker()`](https://rladies.github.io/jinx/reference/recommend_speaker.md) |
| Contributors | [`contributor_welcome()`](https://rladies.github.io/jinx/reference/welcome_contributor.md), [`list_org_contributors()`](https://rladies.github.io/jinx/reference/list_org_contributors.md), `update_contributors_md()` |
| i18n | [`i18n_translations_validate()`](https://rladies.github.io/jinx/reference/validate_translations.md), [`i18n_coverage_check()`](https://rladies.github.io/jinx/reference/check_translation_coverage.md) |
| Slack | [`slack_invite_send()`](https://rladies.github.io/jinx/reference/send_slack_invite.md), [`slack_post_message()`](https://rladies.github.io/jinx/reference/post_slack_message.md), [`slack_welcome_member()`](https://rladies.github.io/jinx/reference/welcome_slack_member.md) |

`/jinx help` in Slack or any issue comment prints the full slash-command
reference. The same list lives in
[`inst/commands/help.md`](https://rladies.github.io/jinx/inst/commands/help.md).

## Setup

### GitHub App (the `jinx[bot]` identity)

1.  Register the app at
    [`rladies/settings/apps/new`](https://github.com/organizations/rladies/settings/apps/new)
    with the name `jinx`.
2.  Permissions:
    - Repository: Issues (R/W), Pull Requests (R/W), Contents (Read)
    - Organization: Members (R/W), Administration (Read)
3.  Events: `issue_comment`, `issues`, `pull_request`.
4.  Install on the RLadies+ org.
5.  Repo variables/secrets: set `JINX_APP_ID` (variable) and
    `JINX_PRIVATE_KEY` (secret).

Detailed conventions, secrets, and workflow-by-workflow notes are in
[`.github/AGENTS.md`](https://rladies.github.io/jinx/AGENTS.md).

### Cross-repo PR review

Other RLadies+ repos opt into Jinx’s PR review by adding:

``` yaml
# .github/workflows/jinx-review.yml
name: PR Review
on:
  pull_request:
    types: [opened, reopened, synchronize]
jobs:
  review:
    uses: rladies/jinx/.github/workflows/reusable-pr-review.yml@main
    secrets: inherit
```

### Cloudflare Worker (Slack bridge)

The worker at `https://jinx.rladies.workers.dev` handles the OAuth
install flow, slash commands, `@`-mention events, and the Airtable
invite approval pipeline. Worker source is in
[`worker/src/`](https://rladies.github.io/jinx/worker/src/); deploy via
`.github/workflows/infra-deploy-worker.yml`. Required worker secrets and
KV bindings are documented in
[`.github/AGENTS.md`](https://rladies.github.io/jinx/AGENTS.html#cloudflare-worker).

## Development

``` r

# Install dev dependencies
install.packages(c("devtools", "testthat", "httptest2", "withr"))

# Load + test the package
devtools::load_all()
devtools::test()

# Full R CMD check
devtools::check()
```

Worker:

``` sh
# Validate the bundle without deploying
npx --yes wrangler@4 deploy --dry-run --outdir /tmp/worker-dist
```

Vignettes:

- [Getting
  started](https://rladies.github.io/jinx/articles/getting-started.html)
- [Workflows](https://rladies.github.io/jinx/articles/workflows.html)
- [Slack app](https://rladies.github.io/jinx/articles/slack-app.html)

## Architecture

Jinx is a regular R package. GitHub Actions workflows call exported
functions; the `gh` package authenticates via the App-minted
`GITHUB_TOKEN` and posts back as `jinx[bot]`.

Bot-facing workflows use the prebuilt `ghcr.io/rladies/jinx-bot:latest`
image so they boot with the current package already installed. The image
is rebuilt by `.github/workflows/infra-build-bot-image.yml` when the
runtime files change.

    Slack / issue comment / cron
            │
            ▼
    GitHub Actions workflow
            │  (jinx[bot] App-token authed)
            ▼
    jinx::cmd_parse() ─► jinx::cmd_execute()
            │
            ▼
    gh::gh() API call as jinx[bot]
            │
            ▼
    reply posted (Slack response_url / issue comment)

For the Slack path, the Cloudflare Worker sits in front of GitHub
Actions, OAuthing into each workspace, verifying Slack request
signatures, and dispatching slash commands via `repository_dispatch`.
Full diagram + endpoint reference in
[`.github/AGENTS.md`](https://rladies.github.io/jinx/AGENTS.html#cloudflare-worker).
