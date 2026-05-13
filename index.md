# jinx ![Jinx the cat, sitting](reference/figures/sprites/sitting.svg)

Jinx is the operations bot for [RLadies+](https://rladies.org/). It runs
on GitHub Actions as `jinx[bot]`, with a Cloudflare Worker bridging
Slack to the same machinery.

Organisers reach Jinx two ways — by typing `/jinx ...` in Slack, or by
posting `/jinx ...` as a comment on any issue or PR in an RLadies+ repo.
Either way, the same R package answers.

Day to day, Jinx handles organiser onboarding, directory PR review,
chapter monitoring, announcements, reports, event sync, translation
checks, and Slack invites for the RLadies+ community.

## Documentation

The [pkgdown site](https://rladies.github.io/jinx/) is split by
audience:

- **For organisers using Jinx** — [Getting
  started](https://rladies.github.io/jinx/articles/jinx.html) and [The
  Jinx Slack
  app](https://rladies.github.io/jinx/articles/slack-app.html).
- **For admins maintaining Jinx** — [Operating
  Jinx](https://rladies.github.io/jinx/articles/workflows.html) and [How
  Jinx is
  built](https://rladies.github.io/jinx/articles/architecture.html).
- **For everyone** — day-to-day RLadies+ organising lives in the
  [RLadies+ Guide](https://guide.rladies.org/); data handling is in
  [PRIVACY.md](https://rladies.github.io/jinx/PRIVACY.md).
