# jinx 0.1.1

## RAG: indexer moved to R

- The content indexer that feeds the Slack bot's Cloudflare Vectorize
  store has been moved from the standalone Node `indexer/` directory
  into the R package. All 8 sources (`hugo-site`, `github-org`,
  `pkgdown-llms`, `github-files`, `github-remote-files`, `events-json`,
  `awesome-creations`, `youtube-channel`) are now configured in
  `inst/config/rag-sources.yml` and implemented as
  `gather_<type>()` functions under `R/rag-source-*.R`. Adding a new
  source is one new R file plus a YAML entry — see the
  [RAG indexer](../articles/rag-indexer.html) article.
- Vector IDs remain `sha256("{repo}|{path}|{chunk_idx}")[1:32]`, so
  the R re-index updates the existing `rladies-content` index in place
  rather than orphaning vectors.
- Hugo pages are now extracted with `rvest` + `rmarkdown::pandoc_convert()`
  (`html → gfm-raw_html`) instead of cheerio + turndown. Pandoc emits
  proper GFM pipe tables where turndown produced flat key/value text;
  other output differs only cosmetically (`-` vs `*` bullets).
- `bot-index-content.yml` now uses `r-lib/actions/setup-r` and calls
  `jinx::rag_index_build()`.

## RAG: surface upcoming events

- The reranker now applies a 1.6× boost to `events` chunks whose
  `date` is in the future, so the handful of upcoming events in the
  index float to the top of the top-5 instead of being drowned out by
  the much larger pool of past events kept on the 365-day trailing
  window.
- For questions that look like event queries ("upcoming events",
  "when's the next meetup", "any workshops soon?", etc.), the
  retriever now runs a second targeted query against the index using
  a fixed event-shaped prompt and merges the resulting `events`
  chunks into the candidate pool before reranking. This rescues
  upcoming events whose cosine similarity to the user's casual
  phrasing would otherwise have left them outside the top-20. The
  fixed event-shaped prompt's embedding is memoised in KV under
  `rag:event_embedding:v1` so the second retrieval only costs one
  extra vector query (no second embed call) after the first warm-up.
- The Jinx system prompt now tells the model to use the "When:" /
  "Status:" lines on event chunks, prefer `Status: upcoming` when the
  user asks about future events, and own it honestly if no upcoming
  events are in the retrieved sources rather than substituting a past
  one.

## Slash-command reply routing

- `/jinx` slash commands from the community workspace previously
  failed with `channel_not_found` because the GHA workflow used the
  organisers' bot token to post into a community channel ID. The
  worker now forwards `team_id` in the dispatch payload, the workflow
  verifies it against `SLACK_ORGANIZER_TEAM_ID` /
  `SLACK_COMMUNITY_TEAM_ID` repo vars, and the reply step posts via
  the workspace-agnostic `response_url` instead of `chat.postMessage`.

## Welcome reusable improvements

- `gh_welcome_contributor()` and `gh_greet_contributor()` gained an
  `extra_message` argument. The string is appended after the standard
  welcome and before the jinx signature, so callers can add a
  project-specific reminder (e.g. "remember to add yourself to
  `.zenodo.json`") without forking the function.
- `reusable-welcome-contributor.yml` now accepts a matching
  `extra_message` workflow input and forwards it via an environment
  variable (no string interpolation into the R source, so the input is
  safe to set to any markdown).
- The reusable also fires on `pull_request_target` opens, so callers
  that need to welcome fork-PR authors can switch their trigger
  without losing the welcome step.

## Module reorganisation

- New `gh_*` module for reusable GitHub PR/issue automation. Functions
  moved out of the contributor/website modules so they can be wired into
  any repo, not just the website:
  - `contributor_welcome()` → `gh_welcome_contributor()`
  - `contributor_thank()` → `gh_thank_contributor()`
  - `contributor_greet()` → `gh_greet_contributor()`
  - `blog_post_checklist()` → `gh_post_checklist()` (also generalised:
    the message now opens with "Thank you for submitting a post" so it
    applies to blog _and_ news content equally; the path filter on the
    caller workflow already covers both).
- `chapter_get_language()` → `i18n_get_chapter_language()` (it has
  always lived in `R/i18n.R`, now follows the `<module>_<verb>_*`
  pattern).
- Internal helpers `directory_validation_row()` and
  `directory_empty_validation_df()` in `R/i18n-validate.R` renamed to
  `i18n_validation_row()` / `i18n_empty_validation_df()` (they validate
  translations, not directory entries).
- Reusable workflows: `reusable-website-blog-checklist.yml` →
  `reusable-post-checklist.yml`. `reusable-welcome-contributor.yml`
  and `reusable-thank-contributor.yml` updated to call the new names.

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
