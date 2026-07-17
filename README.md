# jinx <span class="jinx-sprite" style="float: right;"><img src="man/figures/sprites/sitting.svg" height="120" alt="Jinx the cat, sitting" /></span>

Jinx is the operations bot for [RLadies+](https://rladies.org/).
It runs on GitHub Actions as `jinx[bot]`, with a Cloudflare Worker bridging Slack to the same machinery.

Organisers reach Jinx two ways — by typing `/jinx ...` in Slack, or by posting `/jinx ...` as a comment on any issue or PR in an RLadies+ repo.
Either way, the same R package answers.

Day to day, Jinx handles organiser onboarding, directory PR review, chapter monitoring, announcements, reports, event sync, translation checks, and Slack invites for the RLadies+ community.

## Reusable workflows

Jinx ships a handful of reusable GitHub Actions workflows that any RLadies+
repo can adopt with a few lines of YAML. They're in [`.github/workflows/`](.github/workflows/)
and start with `reusable-`:

| Workflow                              | What it does                                                                                                            |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `reusable-welcome-contributor.yml`    | Posts a first-time welcome on a new PR or issue. Accepts an optional `extra_message` for project-specific reminders.    |
| `reusable-thank-contributor.yml`      | Posts a thank-you on a merged PR (different message for first-time vs returning).                                       |
| `reusable-website-blog-checklist.yml` | Posts the blog-review checklist on a PR that touches blog content.                                                      |
| `reusable-pr-review.yml`              | Calls `jinx::review_run()` to label and assign reviewers based on the rules bundled in jinx.                            |
| `reusable-copilot-review.yml`         | Requests a GitHub Copilot review, guided by the grimoire review gates jinx synced into the repo's Copilot instructions. |

### Caller requirements

Every reusable runs inside the [`ghcr.io/rladies/jinx-bot`](https://github.com/rladies/jinx/pkgs/container/jinx-bot) container.
For the runner to pull that image, **the calling workflow must grant the job
`packages: read`**. The simplest pattern is a workflow-level block:

```yaml
permissions:
  contents: read
  packages: read
```

Without this, you'll see `Error response from daemon: denied` at the docker
pull step and the job fails before the welcome/thank/checklist runs.

`JINX_APP_ID` and `JINX_PRIVATE_KEY` are configured as **org-level secrets** in
`rladies`, so any repo in the org inherits them automatically — no per-repo
configuration needed for the secrets themselves. The **jinx GitHub App** does
need to be installed on the calling repo, which is true org-wide today.

A minimal caller looks like:

```yaml
name: Hello on PR or Issue

on:
  pull_request:
    types: [opened, closed]
  issues:
    types: [opened]

permissions:
  contents: read
  packages: read

jobs:
  welcome:
    if: github.event.action == 'opened'
    uses: rladies/jinx/.github/workflows/reusable-welcome-contributor.yml@main
    secrets:
      JINX_APP_ID: ${{ secrets.JINX_APP_ID }}
      JINX_PRIVATE_KEY: ${{ secrets.JINX_PRIVATE_KEY }}

  thank:
    if: github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged == true
    uses: rladies/jinx/.github/workflows/reusable-thank-contributor.yml@main
    secrets:
      JINX_APP_ID: ${{ secrets.JINX_APP_ID }}
      JINX_PRIVATE_KEY: ${{ secrets.JINX_PRIVATE_KEY }}
```

### Copilot reviews (grimoire gates)

Jinx can hand content reviews to **GitHub Copilot**, guided by the
[`rladies/grimoire`](https://github.com/rladies/grimoire) review gates
(brand, blog, social, translation). It's a two-step setup per repo:

1. **Sync the gates once** — run `/jinx copilot-sync <owner/repo>` (or
   `jinx::copilot_sync_repo()`). This opens a PR adding
   `.github/copilot-instructions.md` and path-scoped
   `.github/instructions/*.instructions.md` so Copilot's review speaks the
   RLadies+ brand and voice. Re-run to refresh when grimoire changes.
2. **Wire the reusable** so Copilot is asked to review every content PR.

The Copilot reusable needs `pull-requests: write` (to request the reviewer)
on top of the usual `contents: read` / `packages: read`:

```yaml
name: Copilot review

on:
  pull_request:
    types: [opened, ready_for_review, synchronize]
    paths:
      - "content/**"

permissions:
  contents: read
  packages: read
  pull-requests: write

jobs:
  copilot-review:
    uses: rladies/jinx/.github/workflows/reusable-copilot-review.yml@main
    secrets:
      JINX_APP_ID: ${{ secrets.JINX_APP_ID }}
      JINX_PRIVATE_KEY: ${{ secrets.JINX_PRIVATE_KEY }}
```

On demand, organisers can also run `/jinx review brand|blog|social|translation <pr>`
(e.g. `/jinx review blog rladies/rladies.github.io#42`) from Slack or a
GitHub comment.

## HTTP API for other repos

Beyond the reusable GitHub Actions workflows above, Jinx's Cloudflare Worker
exposes a small authenticated HTTP API so other RLadies+ repos can get
Cloudflare-backed capabilities without holding their own Cloudflare
credentials. First consumer: `rladies/quarto-rladies-report`, for AI-drafted
report prose.

| Route               | What it does                                                                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /ai/generate` | Thin passthrough to the Workers AI binding. Body: `{model, messages, response_format?, max_tokens?}` — `model` must be on a Worker-side allowlist. Returns `{result}` (Workers AI's native response shape). |

Requires `Authorization: Bearer <JINX_API_KEY>` — ask a Jinx admin for the key
rather than requesting a Cloudflare token of your own. A missing or wrong key
gets a `401`. See `.github/AGENTS.md`'s "Endpoint conventions" and "Worker
secrets" sections for the underlying implementation and secret names.

Cloudflare Web Analytics doesn't need an HTTP route: `jinx::rum_collect_analytics()`
is exported directly from this R package (see `R/website-rum.R`) — a calling
repo can add `jinx` as a dependency and call it, rather than going through the
Worker at all.

## Documentation

The [pkgdown site](https://rladies.github.io/jinx/) is split by audience:

- **For organisers using Jinx** — [Getting started](https://rladies.github.io/jinx/articles/jinx.html) and [The Jinx Slack app](https://rladies.github.io/jinx/articles/slack-app.html).
- **For admins maintaining Jinx** — [Operating Jinx](https://rladies.github.io/jinx/articles/workflows.html) and [How Jinx is built](https://rladies.github.io/jinx/articles/architecture.html).
- **For everyone** — day-to-day RLadies+ organising lives in the [RLadies+ Guide](https://guide.rladies.org/); data handling is in [PRIVACY.md](PRIVACY.md).
