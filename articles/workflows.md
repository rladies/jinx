# Operating Jinx

This page is for the people who maintain Jinx — registering the GitHub
App, deploying the Cloudflare Worker, wiring in new commands. If you
just want to use Jinx, [Getting
started](https://rladies.github.io/jinx/articles/jinx.md) is the page
you want.

For the architecture map (what runs where, who triggers it), see [How
Jinx is built](https://rladies.github.io/jinx/articles/architecture.md).
This page is the *operational* counterpart: what you do to stand it up,
change it, and keep it running.

## Register the GitHub App

Jinx posts as `jinx[bot]` because it authenticates as a registered
GitHub App, not a maintainer’s PAT. Set up in *Settings → Developer
settings → GitHub Apps → New* on the org:

- Name: `jinx`.
- Permissions:
  - Repository: Issues (R/W), Pull Requests (R/W), Contents (Read).
  - Organization: Members (R/W), Administration (Read).
- Events: `issue_comment`, `issues`, `pull_request`.
- Install on the RLadies+ org.

Save the App ID, generate a private key, and install the app on every
repo Jinx needs to act in.

## Wire up secrets

Two values are required for every workflow:

- Variable `JINX_APP_ID` — the App ID from the registration above.
- Secret `JINX_PRIVATE_KEY` — the App’s private key, pasted as-is.

Both are read by
[`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
at the top of every workflow. Set them at the org level so new repos
pick them up automatically.

Module-specific secrets are only needed if you want that module’s
features. A missing module secret is not fatal — Jinx skips the module
and logs a hint:

| Secret | Used by |
|----|----|
| `AIRTABLE_API_KEY` | Airtable sync |
| `BSKY_USER`, `BSKY_PASS` | Bluesky announcements |
| `MASTODON_TOKEN` | Mastodon announcements |
| `LINKEDIN_ACCESS_TOKEN` | LinkedIn announcements |
| `SLACK_TOKEN` | Slack management |
| `MAILCHIMP_API_KEY` | Newsletter |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_SITE_TAG` | Website analytics |

## Configuration files

Jinx loads almost everything from data files in `inst/`, so most
operational changes don’t need a code release — just a PR.

- `inst/config/teams.yml` — team definitions: roles, repos, notification
  channels.
- `inst/config/review-rules.yml` — file-path patterns that drive PR
  reviewer assignment.
- `inst/config/labels.yml` — file-path patterns that drive PR labelling.
- `inst/config/conferences.yml`, `events.yml`, `languages.yml` —
  module-specific lists.
- `inst/templates/*.md` — issue-comment replies, onboarding checklists,
  command help. `inst/templates/teams/<name>.md` extends the base
  onboarding checklist for a specific team.
- `inst/translations/` — message translations indexed by language code.

Editing any of these is a normal PR. The bot image rebuild picks them up
on the next push to `main`.

## Adding a new command

Every `/jinx <verb>` flows through the same two functions, defined in
[`R/commands.R`](https://github.com/rladies/jinx/blob/main/R/commands.R):

``` r

cmd <- jinx::cmd_parse("/jinx invite @ada to website")
jinx::cmd_execute(cmd)
```

To add a new verb:

1.  Extend
    [`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md)
    so it returns the structured fields your verb needs.
2.  Extend the dispatch in
    [`cmd_execute()`](https://rladies.github.io/jinx/reference/cmd_execute.md)
    to call your module function.
3.  Add the command to
    [`inst/commands/help.md`](https://github.com/rladies/jinx/blob/main/inst/commands/help.md)
    so `/jinx help` finds it.
4.  Cover the parser case in `tests/testthat/test-commands.R` and the
    module function in its own test file.

That’s it. The `bot-commands.yml` workflow already calls `cmd_parse` +
`cmd_execute` for issue-comment triggers, and the Cloudflare Worker
dispatches Slack-side calls into the same workflow. You only need to
touch a workflow if your verb needs a new schedule or a separate
trigger.

## Opt another repo into PR review

To add Jinx’s PR review to any RLadies+ repo, drop this workflow in:

``` yaml
# .github/workflows/jinx-review.yml
name: PR review
on:
  pull_request:
    types: [opened, reopened, synchronize]
jobs:
  review:
    uses: rladies/jinx/.github/workflows/reusable-pr-review.yml@main
    secrets: inherit
```

`secrets: inherit` is how the caller repo gets `JINX_APP_ID` and
`JINX_PRIVATE_KEY` from the org-level secrets — no copy-pasting.

The same pattern works for `reusable-welcome-contributor.yml`,
`reusable-thank-contributor.yml`, and `reusable-post-checklist.yml`.

## Copilot reviews (grimoire gates)

Jinx can hand a content review to **GitHub Copilot**, guided by the four
review “gates” in
[rladies/grimoire](https://github.com/rladies/grimoire) — brand, blog,
social, and translation. Grimoire is a set of Claude Agent Skills, and
Copilot only reads its own instruction files, so Jinx bridges the two.
Setup is two steps per repo.

**1. Sync the gates into the repo.** Run
`/jinx copilot-sync <owner/repo>` (or call
[`jinx::copilot_sync_repo()`](https://rladies.github.io/jinx/reference/copilot_sync_repo.md)).
It opens a PR adding `.github/copilot-instructions.md` and path-scoped
`.github/instructions/*.instructions.md` so Copilot’s review speaks the
RLadies+ brand and voice. Re-run it whenever grimoire changes to refresh
the instructions. The gate-to-path mapping lives in
`inst/config/copilot-review.yml` — tune the globs to the target repo’s
layout, then re-sync.

**2. Wire the reusable so Copilot reviews every content PR.** It needs
`pull-requests: write` (to request the reviewer) on top of the usual
`contents: read` / `packages: read`:

``` yaml
# .github/workflows/jinx-copilot-review.yml
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
    secrets: inherit
```

On demand, an organiser can also summon a review from Slack or a GitHub
comment, naming the gate and the PR:

    /jinx review blog rladies/rladies.github.io#42

Copilot posts its findings on the PR as a tiered Blockers / Warnings /
Nits punch list. It is a *pre-human* review gate — it flags issues for a
human to act on, and never approves, merges, or publishes.

Two prerequisites are org-level, not per-repo: Copilot code review must
be enabled on the RLadies+ org, and the jinx GitHub App needs Pull
Requests (R/W) — which the registration above already grants.

## The bot image

Workflows run inside `ghcr.io/rladies/jinx-bot:latest`, which has the
package and all its dependencies pre-installed.
[`infra-build-bot-image.yml`](https://github.com/rladies/jinx/blob/main/.github/workflows/infra-build-bot-image.yml)
rebuilds it when `DESCRIPTION`, `Dockerfile`, or other runtime files
change on `main`. That’s why a typical Jinx command run finishes in a
few seconds — no `install.packages` at run time.

When you add a new R dependency:

1.  Add it to `DESCRIPTION`.
2.  Merge to `main`.
3.  Wait for `infra-build-bot-image` to finish — until then, runs still
    use the old image and your new dependency won’t be there.

## The RAG index

The Slack bot answers questions by retrieving from a Cloudflare
Vectorize index that’s built by Jinx on a weekly schedule. That builder
lives in `R/rag-*.R` and is configured by `inst/config/rag-sources.yml`.
See the [RAG
indexer](https://rladies.github.io/jinx/articles/rag-indexer.md) article
for the contributor guide — what each source does, how to add a new one,
and which env vars the workflow needs.

## The Cloudflare Worker

The Worker at `https://jinx.rladies.workers.dev` is Jinx’s front door
for Slack and Airtable. It’s deployed by
[`infra-deploy-worker.yml`](https://github.com/rladies/jinx/blob/main/.github/workflows/infra-deploy-worker.yml)
on every push to `worker/` on `main`.

Worker secrets are managed through Wrangler:

``` bash
cd worker
wrangler secret put SLACK_SIGNING_SECRET
wrangler secret put SLACK_CLIENT_ID
wrangler secret put SLACK_CLIENT_SECRET
wrangler secret put GITHUB_PAT
wrangler secret put JINX_API_KEY
```

`JINX_API_KEY` backs the `/ai/generate` HTTP API route (see the “HTTP
API for other repos” section of the README) — other RLadies+ repos
authenticate to it with this bearer key.

KV namespaces (`SLACK_TOKENS`, `AIRTABLE_BASES`) and the Vectorize index
(`rladies-content`) are declared in `wrangler.jsonc` — adding one means
editing that file, not running a command.

For what the Worker actually does end-to-end, see [How Jinx is
built](https://rladies.github.io/jinx/articles/architecture.md).

## When things break

- **A workflow run failed.** Open the [Actions
  tab](https://github.com/rladies/jinx/actions), find the red run, and
  read the `cli` log of the failing step. Most module functions print
  their own context.
- **A Slack `/jinx ...` got no reply.** Tail the Worker (`wrangler tail`
  from `worker/`). Failures here are almost always signature
  verification, a missing env var, or a Slack scope that wasn’t granted.
- **A scheduled job didn’t run.** GitHub disables scheduled workflows on
  inactive repos. Trigger one manually from the Actions UI and the
  schedule resumes.
- **A new command is wired but Slack says “unknown command”.** The bot
  image hasn’t rebuilt yet — wait for `infra-build-bot-image` to finish,
  then try again.

The audit log is the Actions run history. Logs for runs older than 14
days are gone; if you need to preserve evidence, screenshot it before
the retention window closes.

## Where to go next

- [How Jinx is
  built](https://rladies.github.io/jinx/articles/architecture.md) — the
  surface map between R package, workflows, and Worker.
- [Privacy policy](https://rladies.github.io/jinx/articles/privacy.md) —
  what data Jinx receives, where it goes, how to request deletion.
- The [function
  reference](https://rladies.github.io/jinx/reference/index.md) — every
  exported function, grouped by module.
