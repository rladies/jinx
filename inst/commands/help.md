**jinx** - RLadies+ GitHub organization bot

**Commands:**

| Command                                              | Description                                                                                |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `/jinx invite @user to <team>`                       | Invite a user to the org and a team                                                        |
| `/jinx offboard @user from <team>`                   | Start offboarding a user from a team                                                       |
| `/jinx announce <post-url>`                          | Announce a blog post on social media                                                       |
| `/jinx chapter-health`                               | Check chapter activity health                                                              |
| `/jinx blog-add <url>`                               | Auto-create a blog entry from URL                                                          |
| `/jinx blog-check-links`                             | Check all blog URLs for broken links                                                       |
| `/jinx report weekly\|monthly`                       | Generate an activity report                                                                |
| `/jinx report chapters`                              | Generate chapter health report                                                             |
| `/jinx chapter-setup <city> <country>`               | Create chapter setup issue                                                                 |
| `/jinx chapter-update <city> <country>`              | Create chapter update issue                                                                |
| `/jinx gha-dashboard`                                | Generate GitHub Actions status report                                                      |
| `/jinx contributors [repo]`                          | List contributors for a repo                                                               |
| `/jinx contributors update [repo]`                   | Update contributors list via PR                                                            |
| `/jinx contributors org`                             | Show top org-wide contributors                                                             |
| `/jinx events <chapter>`                             | List recent events for a chapter                                                           |
| `/jinx events sync`                                  | Sync and publish event summary                                                             |
| `/jinx analytics`                                    | Generate analytics dashboard                                                               |
| `/jinx generate website analytics [period]`          | Generate Cloudflare website report (not yet implemented)                                   |
| `/jinx cfp list`                                     | List open calls for proposals                                                              |
| `/jinx cfp add <conf> <deadline> <url>`              | Track a new CFP                                                                            |
| `/jinx cfp recommend <conf> @speaker`                | Recommend a speaker                                                                        |
| `/jinx poll create <title> days=…`                   | Create a meeting-time poll: `days=` `from=` `to=` `slot=` (+ `tz=` `kind=dates\|weekdays`) |
| `/jinx poll best <id>`                               | Show the top meeting times for a poll                                                      |
| `/jinx translate status`                             | Check translation coverage                                                                 |
| `/jinx translate validate [lang]`                    | Validate translation placeholders                                                          |
| `/jinx slack-invite <email>`                         | Post a Slack invite request for an organiser to action                                     |
| `/jinx remind stale`                                 | Send reminders on stale issues                                                             |
| `/jinx review brand\|blog\|social\|translation <pr>` | Summon Copilot to run a grimoire review gate on a PR                                       |
| `/jinx copilot-sync <owner/repo>`                    | Sync grimoire review gates into a repo's Copilot instructions                              |
| `/jinx setup-channel`                                | Pin RLadies+ resource bookmarks in the current channel                                     |
| `/jinx pair @alice @bob [message]`                   | Open a group DM with mentioned users (up to 7)                                             |
| `/jinx remind-me <when> \| <what>`                   | Set a personal Slack reminder for yourself                                                 |
| `/jinx feedback [days]`                              | _(Global Team)_ Reaction signal on Jinx's recent answers                                   |
| `/jinx questions [days]`                             | _(Global Team)_ What folks asked, the gaps Jinx couldn't answer, and 👎'd replies          |
| `/jinx help`                                         | Show this help message                                                                     |

**Teams:** abstract-review, blog, campaigns, chapter-activity, chapter-onboarding, coc, communications, community-slack, conference-liaison, directory, meetup-pro, mentoring, rocur, translation, website

**DM Jinx or open the Assistant panel** to ask any RLadies+ question — Jinx searches the guide and the website. React to Jinx's answers with 👍 / 👎 / ❤️ so we can track which replies are useful.
