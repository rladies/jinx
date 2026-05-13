# Getting started with Jinx

![Jinx the cat sitting at a laptop, paws on the
keys](../reference/figures/sprites/working.svg)

An organiser wants to invite someone to the website team. A new chapter
in Berlin needs setting up. A blog post just landed and should go out on
Bluesky, Mastodon, LinkedIn, and the newsletter. None of these are hard.
They pile up.

Jinx is the bot you hand them to.

## Where you’ll find Jinx

You talk to Jinx in two places, and the same command does the same thing
in both.

### In Slack

In the RLadies+ organisers Slack, type `/jinx help` to see everything
Jinx knows how to do. `@`-mention Jinx in any channel it’s been added to
and it will search the [RLadies+ Guide](https://guide.rladies.org/) and
reply in-thread.

    /jinx invite @ada to website
    @Jinx how do I start a new chapter?

The Slack side has its own page — see [The Jinx Slack
app](https://rladies.github.io/jinx/articles/slack-app.md) for install,
scopes, and what Jinx does with what you say.

### In a GitHub comment

Post `/jinx <verb>` as a comment on any issue or PR in an RLadies+ repo.
Jinx replies right under the comment, as `jinx[bot]`.

    /jinx report weekly
    /jinx chapter-setup Berlin Germany
    /jinx announce https://rladies.org/blog/<slug>/

There’s no setup on your end — if you have RLadies+ organiser access,
you can summon Jinx.

## What Jinx is doing under the hood

The commands above all flow through the same R package. A `/jinx ...`
from Slack lands at a Cloudflare Worker that dispatches a GitHub Actions
workflow; a `/jinx ...` in a comment fires the same workflow directly.
Either way, Jinx parses the command, runs the matching R function, and
posts the reply.

You don’t need to know any of that to use Jinx. You do need to know it
if you’re trying to add a new command, in which case head to [Operating
Jinx](https://rladies.github.io/jinx/articles/workflows.md).

## When something goes wrong

Jinx is volunteer-maintained and occasionally has bad days.

- Run `/jinx help` first — it’s easy to mistype a verb.
- Recent runs are in the [rladies/jinx Actions
  tab](https://github.com/rladies/jinx/actions); a red run is almost
  always self-explanatory.
- For anything else, open an issue at
  <https://github.com/rladies/jinx/issues>.

For what data Jinx receives, how long it’s kept, and how to ask for it
to be deleted, see the [privacy
policy](https://rladies.github.io/jinx/articles/privacy.md).

## Where to go next

- [The Jinx Slack
  app](https://rladies.github.io/jinx/articles/slack-app.md) — install,
  scopes, the Slack-side flows.
- [Operating Jinx](https://rladies.github.io/jinx/articles/workflows.md)
  — for admins maintaining Jinx’s GitHub App, secrets, and workflows.
- [How Jinx is
  built](https://rladies.github.io/jinx/articles/architecture.md) — the
  architecture map, if you’re about to open a PR that crosses surfaces.
