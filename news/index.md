# Changelog

## jinx (development version)

### Jinx assistant

- **Jinx now keeps an anonymous question-improvement log so the corpus
  can evolve.** Every `@Jinx` mention or DM records the question text
  and a coarse outcome (`answered`, `no_match`, `coding_declined`, or
  `low_confidence`) to a Cloudflare D1 table — with no Slack user id,
  channel, or thread timestamp, so a logged question cannot be traced to
  who asked. Answers are linked so a 👍/👎 reaction updates that
  question’s score, turning “which answers were weak” into a maintainer
  to-do list. `/jinx questions [days]` surfaces the top gaps and
  most-downvoted answers; rows are purged after 180 days by a daily
  cron. Reading the log (via `/jinx questions` and `/jinx feedback`) is
  restricted to the global team, reusing the same Airtable member
  directory as
  [`cmd_authorize()`](https://rladies.github.io/jinx/reference/cmd_authorize.md).
  Requires provisioning a `jinx-question-log` D1 database (see
  `wrangler.jsonc`).

### Directory

- **The automated review lists clickable profile links instead of
  probing them.**
  [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
  used to HTTP-check whether each social handle resolved, but the
  platforms block bot requests, so nearly every entry was flagged (“may
  not resolve”) — noise that trained reviewers to ignore the report. It
  now renders each entry’s socials as ready-made links the reviewer
  clicks to confirm. Also fixes the Mastodon URL builder, which returned
  `NA` for the normal `@user@instance` form.

- **[`directory_sync_airtable()`](https://rladies.github.io/jinx/reference/directory_sync_airtable.md)
  now produces real directory entries.** It reads the live submissions
  base (`appzYxePUruG9Nwyg`, table `submissions`) with its linked
  `languages`, `countries`, and `interests` tables, and writes the full
  entry schema (`data/json/<slug>.json`), profile photos (`data/img/`),
  and contact emails (`contact/<slug>.json`). Returning submitters are
  matched to their existing entry by slug (`directory_id`, falling back
  to `identifier`) and merged as a partial update — `clear_fields` are
  wiped first, then submitted fields overlay the rest. Only genuinely
  changed files are committed (order- and formatting-insensitive
  comparison), and delete requests are reported in the PR body rather
  than executed. Replaces the earlier stub that targeted a placeholder
  base and wrote a name-plus-socials shape.

- **The directory sync runs from the private `rladies/directory` repo,
  not jinx.** Directory submissions carry confidential data (contact
  emails), and jinx is public, so the sync and its logs must stay in the
  private repo, which installs jinx and calls
  [`directory_sync_airtable()`](https://rladies.github.io/jinx/reference/directory_sync_airtable.md).
  With the global-team sync also gone, the public
  `ops-airtable-sync.yml` workflow is removed.

- **[`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
  is now a real automated review**, posting one consolidated comment on
  directory PRs covering filenames, likely-duplicate slugs,
  contact-method vs. social-entry consistency, stray contact info in
  free text, and whether social handles resolve — run from the private
  repo’s review workflow. Handle normalisation now also covers github
  and bluesky.

- The bundled `directory-entry.json` schema now matches the full entry
  shape (location, social media, interests, languages, activities, work,
  photo).

### Copilot reviews

- **Jinx can summon GitHub Copilot to run the grimoire review gates.**
  [`copilot_sync_repo()`](https://rladies.github.io/jinx/reference/copilot_sync_repo.md)
  fetches the four
  [rladies/grimoire](https://github.com/rladies/grimoire) review skills
  (brand, blog, social, translation) plus the foundation brand ruleset
  and lands them in a target repo as `.github/copilot-instructions.md`
  and path-scoped `.github/instructions/*.instructions.md` via a pull
  request — the bridge that makes Copilot’s code review grimoire-aware.
  Run it with `/jinx copilot-sync <owner/repo>`.
- **On-demand and automatic reviews.**
  `/jinx review brand|blog|social|translation <pr>` (accepting `#42`,
  `owner/repo#42`, or a PR URL, plus
  `brand-check`/`blog-review`/`social-review`/`translate-review`
  aliases) requests a Copilot review on a PR and posts a scoping comment
  via
  [`copilot_review_pr()`](https://rladies.github.io/jinx/reference/copilot_review_pr.md).
  The new `reusable-copilot-review.yml` workflow does the same
  automatically when a content PR opens. Both commands are gated to the
  global team.

### Security

- **Privileged commands now require global-team membership.**
  [`cmd_authorize()`](https://rladies.github.io/jinx/reference/cmd_authorize.md)
  gates every command before execution: read-only actions (help,
  reports, analytics, dashboards, lookups) stay open, while any mutating
  command (invite, offboard, chapter/CFP/poll creation, syncs, …)
  requires the requester to appear in the global team member directory
  in Airtable. GitHub commands are matched on the commenter’s login;
  Slack slash commands are matched on the signed `user_name`. The check
  fails closed — unknown actors and directory lookup failures are both
  denied — closing a path where any member of an allowlisted Slack
  workspace could trigger privileged GitHub actions. New commands are
  privileged by default until explicitly declared safe.
- **Privileged Slack commands are restricted to the organisers
  workspace.** The Slack `user_name` is mutable and workspace-scoped,
  and the community workspace is openly joinable, so a colliding handle
  there must not authorize privileged actions.
  [`cmd_authorize()`](https://rladies.github.io/jinx/reference/cmd_authorize.md)
  only honors privileged Slack commands originating from the organisers
  workspace; read-only commands are unaffected.
- **Command privilege is now keyword-labelled at each handler.**
  Commands are declared in a single registry, each tagged `jinx_safe` or
  `jinx_gated` next to its handler; dispatch and the safe/gated
  classification both derive from it, and a test asserts every command
  carries a keyword and every parseable action is registered. Replaces
  the separate hand-maintained safe-command list, so a new command is
  labelled where it is defined.

### Bug fixes

- **`/jinx chapter-health` now reports real data.** The command was a
  placeholder that echoed “Checking chapter health…”; it now runs the
  health check and summarises inactive chapters.
- **`/jinx blog-add <url>` now opens a PR.** New
  [`blog_add_pr()`](https://rladies.github.io/jinx/reference/blog_add_pr.md)
  fetches the page metadata and opens a PR adding the entry to
  awesome-rladies-creations (skipping domains already listed); the
  command previously only echoed the URL.
- **`/jinx blog-check-links` now checks real links.** New
  [`blog_check_links_repo()`](https://rladies.github.io/jinx/reference/blog_check_links_repo.md)
  reads the community blog entries from awesome-rladies-creations and
  reports broken URLs/feeds; the command previously only echoed
  “Checking blog links…”.
- **[`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md)
  now derives the filename correctly.** The domain was extracted by
  stripping from the first `/`, which is inside `https://`, so every
  entry collapsed to `https.json`. Protocol is now stripped before the
  path.
- **Removed `/jinx validate-directory`.** Directory entries are already
  validated on every push and PR by the directory repo’s own
  `validate_jsons.yml`; the jinx command duplicated it and did nothing.
- **[`slack_subscribe_rss()`](https://rladies.github.io/jinx/reference/slack_subscribe_rss.md)
  posts an actionable request.** It previously sent
  `/feed subscribe <url>` as a bot message, which Slack never executes,
  so nothing was ever subscribed. It now posts a request for a human in
  the channel to run the command.
- **[`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_onboarding.md)
  no longer logs “Granted access” for repo access it never granted.**
  Repo access is conveyed by team membership; the log now states that
  accurately.
- **Removed `gt_sync_airtable()`.** It fetched global-team data and
  discarded it, duplicating the complete sync that already runs weekly
  in the website repo (`scripts/get_global_team.R`). Global-team sync is
  owned there. With the directory sync also moved out of jinx (see
  Directory), the `ops-airtable-sync.yml` workflow is removed entirely.

### Meeting scheduling

- **New meeting-poll module backed by the samkoma API.**
  [`meeting_poll_create()`](https://rladies.github.io/jinx/reference/meeting_poll_create.md)
  opens a “find a time” poll (public by default, returning a host
  `edit_token`),
  [`meeting_poll_get()`](https://rladies.github.io/jinx/reference/meeting_poll_get.md)
  /
  [`meeting_poll_best()`](https://rladies.github.io/jinx/reference/meeting_poll_best.md)
  read responses and ranked slots,
  [`meeting_poll_lock()`](https://rladies.github.io/jinx/reference/meeting_poll_lock.md)
  locks the chosen slot, and
  [`meeting_poll_ics()`](https://rladies.github.io/jinx/reference/meeting_poll_ics.md)
  exports it as an `.ics` file. Exposed in chat via
  `/jinx poll create …` and `/jinx poll best <id>`. Base URL is
  overridable through `SAMKOMA_BASE_URL`. Externally-sourced poll titles
  and participant names are markdown-neutralised before being rendered
  into bot-authored GitHub/Slack messages, so they cannot inject links
  or formatting.
- **Global team onboarding opens an onboarding meeting poll.**
  [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_onboarding.md)
  now calls
  [`gt_schedule_onboarding_meeting()`](https://rladies.github.io/jinx/reference/gt_schedule_onboarding_meeting.md),
  which opens a samkoma poll spanning a two-week window of candidate
  dates starting one week out and posts the poll link to the onboarding
  issue. A samkoma outage warns and is skipped rather than aborting
  onboarding.

### Post-review hardening

- **First-time contributor check actually works.**
  `is_first_time_contributor()` was passing `creator=` to
  `GET /repos/{owner}/{repo}/pulls`, which the API silently ignores —
  every author looked like a first-timer until a repo had more than one
  PR total, and like a returning contributor after that. Now uses
  `GET /search/issues` with `is:pr/is:issue + author:` to count authored
  items correctly.
- **Slack mention stripping handles all forms.**
  `slack_event_strip_mention()` now removes `<@U…|display>` user
  mentions, `<!subteam^S…|name>` group mentions, and
  `<!channel|here|everyone>` broadcasts in addition to the bare `<@U…>`
  form. Previously the bot’s own past mentions could leak into thread
  history as user turns.
- **Slack thread history fails closed without `bot_user_id`.** If the
  team KV record has no cached `bot_user_id` (older installs),
  `slack_thread_history()` now drops the whole history rather than
  relabelling every prior bot reply as `role: "user"`.
- **Slack API retries 429 + 5xx once.** `slack_api_call()` honours
  `Retry-After` (capped at 5s) before raising, so a single rate-limited
  post no longer aborts the answer path with the failure quip.
- **Reaction events deduped by `event_id`.**
  `slack_event_handle_reaction()` now skips duplicate Slack retries of
  the same `reaction_added` event so the daily counters stop
  double-incrementing.
- **Workflow-input injection lane closed.** `ops-chapter-onboarding`,
  `ops-global-team-invite`, `ops-global-team-finalize`,
  `ops-global-team-offboard`, `ops-update-contributors`, and
  `ops-airtable-sync` now move every `${{ inputs.* }}` into an `env:`
  block and read it from
  [`Sys.getenv()`](https://rdrr.io/r/base/Sys.getenv.html) inside
  Rscript. The invite workflow also builds its JSON artifact with `jq`
  instead of `echo` so a `'` in a name no longer crashes the run.
- **Workflow hardening.** All `actions/checkout` steps now set
  `persist-credentials: false`, all ops/CI/infra/reusable workflows get
  `timeout-minutes: 15`, and every self-racing ops workflow gets a
  `concurrency:` group key (the directory sync, contributors update,
  per-username invite/offboard, etc.).
- **`gh_branch_upsert(force = FALSE)` returns the real head.**
  Previously it returned the *base* SHA when the branch already existed,
  which was wrong for any caller that wanted to act on the branch tip.
  Now reads the existing branch’s head SHA instead.
- **Airtable sync retries.**
  [`airtable_list_records()`](https://rladies.github.io/jinx/reference/airtable_list_records.md)
  now wraps each paginated request in `req_retry(max_tries = 3)`, so a
  429 mid-sync no longer aborts the whole pull.
- **Directory slug collisions.** Two records named “Maria” used to
  collide on `maria.json`. `airtable_to_directory_entry()` now appends a
  6-char hash of the Airtable record id to the slug.
- **Contributors update stops daily commit churn.** The equality check
  used to compare the rendered file verbatim, including
  `_Last updated: {Sys.Date()}_`, so it always diffed and committed
  daily even when no contributors had changed. The check now strips that
  line before comparing.
- **`is_team_member` fails open on transient errors.** A real 404 still
  returns `FALSE`, but a network blip or 5xx returns `TRUE` (with a
  warning) so we don’t spam the global team with first-timer welcomes
  during a GitHub hiccup.
- **`review_assign_onboarding` surfaces errors.** Comment-post failures
  now emit a `cli_alert_warning` instead of being swallowed silently, so
  a failed `cc `[`@rladies`](https://github.com/rladies)`/...` tag is
  visible in the run log.
- **Event-embedding KV write gets a 30-day TTL** so a stale vector
  doesn’t outlive the model behind it.

### Slack bot: remember the thread

- The Slack Q&A bot now reads prior turns in the same thread via
  `conversations.replies` before calling the LLM, so follow-up questions
  no longer require restating the whole conversation. Up to the last 8
  turns (capped at ~4k chars) are passed in as `user`/`assistant`
  history. Applies to both assistant DM threads and channel
  `app_mention` threads. The user’s two most recent prompts are also
  folded into the retrieval embedding so the right sources surface when
  the new question is a one-word follow-up.

### Airtable directory sync: actually open a PR

- [`directory_create_pr()`](https://rladies.github.io/jinx/reference/directory_create_pr.md)
  was a stub that returned the directory’s pulls-page URL without
  creating a branch, writing files, or opening a PR. The function now
  creates a dated `jinx/airtable-sync-YYYYMMDD` branch, commits each
  changed `contact/{slug}.json` file via the contents API, and opens a
  PR back into `main` (returning the URL of an existing open PR if the
  branch was already in flight).
- `write_directory_entries()` now returns a list of
  `{filename, path, content, sha}` records for changed entries instead
  of only their filenames, so the PR step can actually write them.

### Reports: stop publishing to global-team

- The weekly activity, monthly chapter-health, analytics dashboard, and
  GitHub Actions dashboard ops workflows no longer open issues in
  `rladies/global-team`. The publish helpers (`report_publish()`,
  `analytics_publish_dashboard()`, `gha_publish_dashboard()`,
  `event_publish_summary()`) and the matching scheduled workflows have
  been removed.
- [`chapter_report_health()`](https://rladies.github.io/jinx/reference/chapter_report_health.md)
  now returns the formatted markdown body instead of opening an issue.
- `ops-event-sync.yml` keeps the meetup sync but no longer publishes a
  summary issue.

### Contributors: push directly to main

- [`contributor_update()`](https://rladies.github.io/jinx/reference/contributor_update.md)
  now commits the rendered contributors file straight to the default
  branch (`main` by default) and returns the commit URL. The previous
  behaviour of opening a `jinx/update-contributors` branch and PR has
  been removed. The `ops-update-contributors` workflow now declares
  `contents: write`.

### RAG: tolerate malformed JSON fields

- The `awesome-rladies-creations` packages feed has 41 entries where
  `pkdown_url` and/or `repo_url` parse as empty JSON objects
  ([`{}`](https://rdrr.io/r/base/Paren.html)) rather than strings or
  `null`. The scheduled indexer crashed mid-run on 2026-05-24 with
  `missing value where TRUE/FALSE needed` when one of these reached
  [`nzchar()`](https://rdrr.io/r/base/nchar.html). The custom `%or%`
  operator and the downstream
  [`nzchar()`](https://rdrr.io/r/base/nchar.html) checks now go through
  a new
  [`is_blank()`](https://rladies.github.io/jinx/reference/is_blank.md)
  helper that treats NULL, zero-length vectors and lists, NA, and the
  empty string uniformly as “missing”. Regression tests pin the
  empty-list and NA cases.
- [`parse_unix_date()`](https://rladies.github.io/jinx/reference/parse_unix_date.md)
  no longer errors when handed an empty list or any other non-character
  / non-numeric value; it returns `NULL`, matching its behaviour for
  `NULL` and `""`.

### RAG: answer “when is the next event” across all chapters

- **The events indexer now emits a cross-chapter digest chunk.** Asking
  Jinx for the next upcoming event used to fail whenever the soonest
  events happened to sit outside the handful of per-event chunks that
  vector search retrieved — “upcoming-ness” is a structured filter, not
  a semantic property, and only a few events are upcoming at any time (5
  of 5,221 in the feed).
  [`gather_events_json()`](https://rladies.github.io/jinx/reference/gather_events_json.md)
  now also builds a single `events-digest` chunk
  ([`events_digest_chunk()`](https://rladies.github.io/jinx/reference/events_digest_chunk.md))
  listing every upcoming event globally, soonest first, with a per-event
  link and venue. The worker pins this digest into context for
  event-intent questions so it always reaches the model, boosts its
  source weight, and allows the digest’s embedded per-event links to be
  cited.
  [`gather_all_chunks()`](https://rladies.github.io/jinx/reference/gather_all_chunks.md)
  now honours a chunk’s own `source_type`, falling back to the source
  default.
- Digest rendering is hardened against untrusted feed content: events
  with a missing or unparseable date sort last (not first, where they
  would be quoted as the next event), and Slack link metacharacters in
  meetup titles are neutralised so they cannot corrupt the rendered
  link.
- **[`parse_unix_date()`](https://rladies.github.io/jinx/reference/parse_unix_date.md)
  no longer crashes the indexer on a malformed date string.**
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) with the
  default format raises an error (not a warning) on an unparseable
  string, which
  [`suppressWarnings()`](https://rdrr.io/r/base/warning.html) does not
  catch; a single bad date in the feed would abort the whole index
  build. Parse failures now degrade to `NULL`.

## jinx 0.1.1

### RAG: indexer moved to R

- The content indexer that feeds the Slack bot’s Cloudflare Vectorize
  store has been moved from the standalone Node `indexer/` directory
  into the R package. All 8 sources (`hugo-site`, `github-org`,
  `pkgdown-llms`, `github-files`, `github-remote-files`, `events-json`,
  `awesome-creations`, `youtube-channel`) are now configured in
  `inst/config/rag-sources.yml` and implemented as `gather_<type>()`
  functions under `R/rag-source-*.R`. Adding a new source is one new R
  file plus a YAML entry — see the [RAG
  indexer](https://rladies.github.io/jinx/articles/rag-indexer.md)
  article.
- Vector IDs remain `sha256("{repo}|{path}|{chunk_idx}")[1:32]`, so the
  R re-index updates the existing `rladies-content` index in place
  rather than orphaning vectors.
- Hugo pages are now extracted with `rvest` +
  [`rmarkdown::pandoc_convert()`](https://pkgs.rstudio.com/rmarkdown/reference/pandoc_convert.html)
  (`html → gfm-raw_html`) instead of cheerio + turndown. Pandoc emits
  proper GFM pipe tables where turndown produced flat key/value text;
  other output differs only cosmetically (`-` vs `*` bullets).
- `bot-index-content.yml` now uses `r-lib/actions/setup-r` and calls
  [`jinx::rag_index_build()`](https://rladies.github.io/jinx/reference/rag_index_build.md).
- Hugo page fetches are parallelised via
  [`httr2::req_perform_parallel`](https://httr2.r-lib.org/reference/req_perform_parallel.html)
  (`max_active = 8`) to match the throughput of the JS pool the indexer
  replaced.
- [`gather_rag_source()`](https://rladies.github.io/jinx/reference/gather_rag_source.md)
  now hard-errors on an unknown source type so a YAML typo in
  `inst/config/rag-sources.yml` aborts the run rather than silently
  skipping a source on the weekly cron.
- Cloudflare API calls (embed, upsert, account-id discovery) inherit a
  `req_retry(max_tries = 3)` policy via the base
  [`cloudflare_request()`](https://rladies.github.io/jinx/reference/cloudflare_request.md)
  helper, so a transient 5xx no longer kills the whole indexer.
- Fixed NA propagation in
  [`extract_hugo_page()`](https://rladies.github.io/jinx/reference/extract_hugo_page.md)
  that could embed the literal string `"NA"` into chunk text when a Hugo
  page was missing a `<title>` or `<meta name="description">` tag.

### RAG: surface upcoming events

- The reranker now applies a 1.6× boost to `events` chunks whose `date`
  is in the future, so the handful of upcoming events in the index float
  to the top of the top-5 instead of being drowned out by the much
  larger pool of past events kept on the 365-day trailing window.
- For questions that look like event queries (“upcoming events”, “when’s
  the next meetup”, “any workshops soon?”, etc.), the retriever now runs
  a second targeted query against the index using a fixed event-shaped
  prompt and merges the resulting `events` chunks into the candidate
  pool before reranking. This rescues upcoming events whose cosine
  similarity to the user’s casual phrasing would otherwise have left
  them outside the top-20. The fixed event-shaped prompt’s embedding is
  memoised in KV under `rag:event_embedding:v1` so the second retrieval
  only costs one extra vector query (no second embed call) after the
  first warm-up.
- The Jinx system prompt now tells the model to use the “When:” /
  “Status:” lines on event chunks, prefer `Status: upcoming` when the
  user asks about future events, and own it honestly if no upcoming
  events are in the retrieved sources rather than substituting a past
  one.

### Slash-command reply routing

- `/jinx` slash commands from the community workspace previously failed
  with `channel_not_found` because the GHA workflow used the organisers’
  bot token to post into a community channel ID. The worker now forwards
  `team_id` in the dispatch payload, the workflow verifies it against
  `SLACK_ORGANIZER_TEAM_ID` / `SLACK_COMMUNITY_TEAM_ID` repo vars, and
  the reply step posts via the workspace-agnostic `response_url` instead
  of `chat.postMessage`.

### Welcome reusable improvements

- [`gh_welcome_contributor()`](https://rladies.github.io/jinx/reference/gh_welcome_contributor.md)
  and
  [`gh_greet_contributor()`](https://rladies.github.io/jinx/reference/gh_greet_contributor.md)
  gained an `extra_message` argument. The string is appended after the
  standard welcome and before the jinx signature, so callers can add a
  project-specific reminder (e.g. “remember to add yourself to
  `.zenodo.json`”) without forking the function.
- `reusable-welcome-contributor.yml` now accepts a matching
  `extra_message` workflow input and forwards it via an environment
  variable (no string interpolation into the R source, so the input is
  safe to set to any markdown).
- The reusable also fires on `pull_request_target` opens, so callers
  that need to welcome fork-PR authors can switch their trigger without
  losing the welcome step.

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
