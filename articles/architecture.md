# How Jinx is built

Jinx is one bot but lives in three places. This article maps each
surface — what code runs where, who triggers it, and how the pieces talk
to each other. Use it as orientation before opening a PR that crosses
surfaces.

## The map

    +--------------------+      +-------------------------+
    |  Slack workspace   |      |   GitHub (rladies/*)    |
    |                    |      |                         |
    |  /jinx ...         |      |  /jinx ... in a comment |
    |  @Jinx ...         |      |  PR opened, push, cron  |
    |  Block Kit clicks  |      |                         |
    +---------+----------+      +------------+------------+
              |                              |
              v                              v
    +---------------------+        +-----------------------+
    |  Cloudflare Worker  | -----> |  GitHub Actions       |
    |  (worker/src/)      |  RPC   |  workflows (.github/) |
    |                     |        |                       |
    |  - OAuth + tokens   |        |  - jinx[bot] App auth |
    |  - signature verify |        |  - bot image w/ pkg   |
    |  - RAG (Vectorize)  |        |  - Rscript -e jinx::* |
    |  - Airtable webhook |        |                       |
    +---------------------+        +----------+------------+
                                              |
                                              v
                                      +---------------+
                                      |  R package    |
                                      |  (this repo)  |
                                      |               |
                                      |  R/, inst/    |
                                      +---------------+

The R package is the source of truth: every workflow boots an image that
has it pre-installed, and the worker exists to put Slack-shaped inputs
onto a workflow trigger so the same R code can answer them.

## The R package

The bulk of Jinx is a regular R package in
[R/](https://github.com/rladies/jinx/tree/main/R) with exported
functions grouped by module — team management, chapters, directory,
blog, announcements, reports, events, conferences, contributors, i18n,
Slack, analytics, and PR review. The [function
reference](https://rladies.github.io/jinx/reference/index.md) lists
everything by group.

Two things distinguish it from a typical R package:

- **Templates and config live in `inst/`.** Issue-comment replies,
  onboarding checklists, command help, translations, and team rules are
  all data files the R functions read at runtime. Editing a template
  never requires a code change.
- **It runs unattended.** Most calls happen on a runner, not in
  someone’s session. Functions log with `cli`, surface errors with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html),
  and prefer returning structured data the workflow can post back.

You can call any exported function locally —
[`gt_invite()`](https://rladies.github.io/jinx/reference/global_team_invite.md),
[`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md),
[`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
— given the right env vars. This is how all of the bot’s behaviour stays
testable without spinning up a workflow.

## GitHub Actions — the `jinx[bot]` runtime

Workflows in
[`.github/workflows/`](https://github.com/rladies/jinx/tree/main/.github/workflows)
are the runtime. They all share the same shape:

1.  Mint an installation token with
    [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
    using `JINX_APP_ID` + `JINX_PRIVATE_KEY`. The token authenticates
    API calls and gives the bot the `jinx[bot]` identity on comments.
2.  Run inside `ghcr.io/rladies/jinx-bot:latest` so the R package and
    all its dependencies are already installed. The image is rebuilt by
    `infra-build-bot-image.yml` when runtime files change.
3.  Call into the package via `Rscript -e 'jinx::...'`.

Workflows fall into four naming buckets:

| Prefix | Trigger | Examples |
|----|----|----|
| `bot-` | Slack / issue-comment / `repository_dispatch` | `bot-commands`, `bot-slack-welcome` |
| `ops-` | Scheduled or manually-dispatched org operations | `ops-report-weekly`, `ops-event-sync` |
| `ci-` | PRs and pushes — checks, never side effects | `ci-r-cmd-check`, `ci-i18n-validate` |
| `infra-` | Builds and deploys — bot image, worker, pkgdown | `infra-deploy-worker`, `infra-build-bot-image` |
| `reusable-` | Called by other repos via `workflow_call` | `reusable-pr-review`, `reusable-welcome-contributor` |

Cross-repo PR review is the only piece other RLadies+ repos opt into
directly — they call `reusable-pr-review.yml` from their own workflow.

## Cloudflare Worker — the Slack / Airtable front door

The worker at `https://jinx.rladies.workers.dev` lives in
[`worker/src/`](https://github.com/rladies/jinx/tree/main/worker/src)
and is the only piece of Jinx that does not run on GitHub
infrastructure. It exists because Slack and Airtable need a low-latency
HTTPS endpoint that Actions cannot provide.

Five things happen here:

- **OAuth and token storage** — `slack-oauth.js` runs the install flow
  and stashes per-workspace bot tokens in Cloudflare KV
  (`SLACK_TOKENS`). The allowlist check (organisers + community
  workspaces only) rejects any install outside RLadies+.
- **Signature verification** — every Slack-side POST runs through
  `slack_signature_verify()` in `slack-api.js` before any business
  logic.
- **Slash commands and mentions** — `slash-command.js` and
  `slack-events.js` translate Slack payloads into `repository_dispatch`
  events that fire the matching `bot-*` workflow, then post the
  workflow’s reply back via `response_url`. Slack sees a normal
  slash-command response; GitHub sees a normal workflow run.
- **RAG answers** — `rag.js` handles `@Jinx`-mention questions by
  querying a Cloudflare Vectorize index of the [RLadies+
  Guide](https://guide.rladies.org/) and the website, then using Workers
  AI for the answer. This path stays entirely inside the worker — no
  GitHub round-trip.
- **Airtable invite approval** — `airtable-invite.js` receives the
  webhook from the public invite form and posts Block Kit cards to the
  organisers’ channel; `slack-interact` handles the Approve / Deny /
  Mark-sent button clicks.

The worker is deployed by `infra-deploy-worker.yml` and configured
through Wrangler secrets and KV bindings, documented in
[`.github/AGENTS.md`](https://github.com/rladies/jinx/blob/main/.github/AGENTS.md#cloudflare-worker).

## How a request flows

Two flows account for almost everything Jinx does.

**`/jinx ...` from anywhere**

    Slack /jinx ...                Issue-comment /jinx ...
           |                                |
           v                                v
       Worker                           bot-commands.yml
      (verify, dispatch)                   (issue_comment)
           |                                |
           +--------> bot-commands.yml <----+
                           |
                           v
                    jinx::cmd_parse()
                    jinx::cmd_execute()
                           |
                           v
                  reply (Slack response_url
                         or gh::gh comment)

The same R code answers Slack and GitHub. The worker’s only job is to
make a Slack request look like a workflow trigger.

**`@Jinx ...` mention**

    Slack @Jinx ...
           |
           v
       Worker
           |
           v
       rag.js  -- Vectorize query --> embedded chunks
           |
           v
       Workers AI (Llama 3.1)
           |
           v
       reply in-thread (chat.postMessage)

Mentions never leave the worker — RAG is fast enough that round-tripping
through Actions would be wasteful.

## Where to make a change

| If you’re changing… | Edit here |
|----|----|
| What a command **does** | `R/` + tests in `tests/testthat/` |
| What a command **looks like in a reply** | `inst/templates/` (and `inst/translations/`) |
| Which trigger or schedule a workflow uses | `.github/workflows/*.yml` |
| How Slack parses a slash command or button | `worker/src/slash-command.js` / `slack-events.js` |
| RAG behaviour, sources, or prompts | `worker/src/rag.js` and the indexer |
| OAuth flow, allowlist, scopes | `worker/src/slack-oauth.js` + Slack app config |

If a change spans surfaces, prefer one PR per surface unless they have
to land together — the bot image rebuild + worker deploy run on separate
workflows and roll out independently.
