# Privacy policy

*Last updated: 2026-07-05*

Jinx is a Slack app and GitHub bot maintained by volunteers for the
**RLadies+** organization. It exists to help RLadies+ run its community
operations — answering questions about the RLadies+ Guide, and running
organization commands such as inviting members, generating reports, and
reminding maintainers about stale issues.

This document describes what data Jinx receives, how it is used, where
it goes, and how to request deletion.

## Who is responsible

Jinx is operated by the RLadies+ Global Team. The technical maintainers
are the contributors listed in the
[rladies/jinx](https://github.com/rladies/jinx) repository on GitHub.

Contact: open an issue at <https://github.com/rladies/jinx/issues>.

## What data Jinx receives

### When you run a `/jinx` slash command

Slack sends Jinx the following fields, as documented in the [Slack slash
command
payload](https://api.slack.com/interactivity/slash-commands#app_command_handling):

- The command text you typed (e.g. `invite @ada to website`)
- Your Slack user ID and username
- The Slack channel ID and name where you ran the command
- A short-lived `response_url` Slack uses to deliver follow-up replies

### When you mention `@Jinx`

Slack sends Jinx the message text (with the mention stripped), your
Slack user ID, the channel ID, and the thread timestamp so the reply can
be posted in-thread.

### Jinx does not receive

- Your email address, real name, or Slack profile fields
- Any messages in channels where you did not explicitly invoke Jinx
- Direct messages between other users
- Any data from channels Jinx is not a member of

## How Jinx uses the data

### `/jinx` slash commands

1.  The Slack request is received by a [Cloudflare
    Worker](https://workers.cloudflare.com/) operated by RLadies+, which
    verifies Slack’s request signature.
2.  The Worker forwards the command payload to the
    [rladies/jinx](https://github.com/rladies/jinx) GitHub repository as
    a `repository_dispatch` event.
3.  A GitHub Actions workflow runs the requested command as the
    `jinx[bot]` GitHub App and posts the result back to Slack using your
    `response_url`.

The command and the Slack user who ran it are recorded in the GitHub
Actions run log so maintainers can audit what Jinx did and why. The
rladies/jinx repository is **public**, which means run logs are publicly
visible.

### `@Jinx` questions

1.  The Cloudflare Worker receives the mention (or your direct message
    to Jinx).
2.  Your question text is sent to [Cloudflare Workers
    AI](https://developers.cloudflare.com/workers-ai/) for embedding and
    to a large language model to generate an answer grounded in the
    RLadies+ Guide and website.
3.  The answer (with source links) is posted back to the Slack thread.
4.  The **text of your question** and a coarse note of how well Jinx
    answered it (answered, came up empty, coding question declined, or
    thin retrieval) are recorded in an anonymous question-improvement
    log, so maintainers can see where the Guide is thin and fill the
    gaps.

The question-improvement log is **anonymous by construction**: no Slack
user ID, username, channel, or thread timestamp is stored alongside the
question, so a logged question cannot be traced back to who asked it.
Because a free-text question can still contain identifying details
someone chooses to type, identifiers are deliberately never recorded
with it, the stored question text is truncated, and rows are
automatically deleted after 180 days. The log is readable only by the
Global Team (via a restricted `/jinx questions` command), not by every
workspace member.

If you react to one of Jinx’s answers with 👍 or 👎, that reaction is
counted against the logged question as an anonymous quality signal — the
identity of the reacting person is never read or stored.

## Where data is stored

| Data | Where | Retention |
|----|----|----|
| Slack request payloads (in transit) | Cloudflare Worker memory | Discarded as soon as the request completes |
| Worker observability logs | Cloudflare | Per [Cloudflare’s data retention](https://developers.cloudflare.com/workers/observability/logs/) — currently 7 days for Workers Logs |
| Command audit trail | GitHub Actions run logs in rladies/jinx | 14 days (repo-level retention configured on rladies/jinx) |
| `@Jinx` question text | Sent to Cloudflare Workers AI for inference | Per [Cloudflare’s AI data policy](https://www.cloudflare.com/trust-hub/) — inputs are not used to train models |
| RAG content index | Cloudflare Vectorize (`rladies-content`) | Contains only public RLadies+ Guide and website text, no user data |
| Pending Slack-invite email | Cloudflare KV (`SLACK_TOKENS`) | 90 days after an organiser marks the invite sent, or consumed (and deleted) the moment the member joins the workspace |
| Reaction feedback (per-emoji count) | Cloudflare KV (`SLACK_TOKENS`) | 180 days — counts only, no message text or user identifiers |
| Question-improvement log | Cloudflare D1 (`jinx-question-log`) | Question text + outcome + anonymous 👍/👎 counts, no identifiers; rows auto-deleted after 180 days |
| Workspace install metadata | Cloudflare KV (`SLACK_TOKENS`) | Until the app is uninstalled from the workspace |

Jinx maintains a small Cloudflare KV store and D1 database described in
the table above. Apart from the anonymous question-improvement log —
question text and outcome, with no identifiers — it does **not** store
the content of your messages or the answers it gives, beyond the
standard observability logs above.

## Who Jinx shares data with

- **GitHub** — to dispatch commands, run workflows, and post replies via
  the GitHub API.
- **Cloudflare** — the Worker runtime, AI inference, and Vectorize index
  all run on Cloudflare infrastructure.
- **Slack** — replies and acknowledgements go back to Slack via the Web
  API.

Jinx does **not** share data with advertisers, analytics providers, or
any third party not listed above. RLadies+ does not sell user data.

## Your rights

You can ask the maintainers to:

- Remove Slack identifiers associated with you from GitHub Actions run
  logs (we will redact the relevant logs and, where possible, delete the
  workflow run).
- Stop responding to your slash commands and mentions (you can also
  simply not invoke Jinx — Jinx never receives data unless you summon
  it).
- Provide a list of the audit-trail entries that reference your Slack
  user ID.

Send requests to **<jinx@rladies.org>** or open a private contact
through a Global Team member. We aim to respond within 30 days.

## Security

- All requests from Slack are verified using Slack’s signing secret
  before any further processing.
- Communication with Slack, GitHub, and Cloudflare uses TLS.
- Secrets (GitHub App private key, Slack signing secret) are stored as
  Cloudflare Worker secrets and GitHub Actions secrets, accessible only
  to deployment and runtime.

Bugs and security issues can be reported privately via the contact email
above.

## Children’s privacy

Jinx is intended for the adult volunteers and members who participate in
the RLadies+ Slack workspace. It is not directed at children under 13
(or under the equivalent age in your jurisdiction).

## Changes to this policy

Material changes will be announced in the
[rladies/jinx](https://github.com/rladies/jinx) repository and the date
at the top of this document will be updated. The version history of this
file is the canonical change log.
