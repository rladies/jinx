# Getting Started with jinx

jinx is the RLadies+ GitHub organization management bot. It is an R
package deployed via GitHub Actions with a registered GitHub App
identity (`jinx[bot]`).

## Architecture

    Issue comment (/jinx invite ...)
      -> issue_comment workflow triggers
        -> installs jinx R package
          -> calls jinx::cmd_parse() + jinx::cmd_execute()
            -> gh::gh() API calls as jinx[bot]
              -> reply comment posted

jinx is a standard R package. GitHub Actions workflows call exported R
functions. The `gh` package handles GitHub API authentication via the
`GITHUB_TOKEN` environment variable. When using a GitHub App token (via
`actions/create-github-app-token`), API calls and comments appear as
`jinx[bot]`.

## Prerequisites

### 1. Register the GitHub App

1.  Go to **Settings \> Developer settings \> GitHub Apps \> New** for
    your org
2.  Name: `jinx`
3.  Permissions:
    - Repository: Issues (R/W), Pull Requests (R/W), Contents (Read)
    - Organization: Members (R/W), Administration (Read)
4.  Events: `issue_comment`, `issues`, `pull_request`
5.  Install on the RLadies+ org

### 2. Configure secrets

In the jinx repo (or org-wide):

- **Variable** `JINX_APP_ID` – the GitHub App’s ID
- **Secret** `JINX_PRIVATE_KEY` – the GitHub App’s private key

Additional secrets for specific modules:

| Secret                   | Module                 |
|--------------------------|------------------------|
| `AIRTABLE_API_KEY`       | Airtable sync          |
| `BSKY_USER`, `BSKY_PASS` | Bluesky announcements  |
| `MASTODON_TOKEN`         | Mastodon announcements |
| `LINKEDIN_ACCESS_TOKEN`  | LinkedIn announcements |
| `SLACK_TOKEN`            | Slack management       |
| `MAILCHIMP_API_KEY`      | Newsletter             |

### 3. Installation

``` r

remotes::install_github("rladies/jinx")
```

## The `/jinx` command system

jinx responds to commands posted as issue comments in any repo where it
is installed. Commands start with `/jinx` followed by an action:

    /jinx invite @username to website
    /jinx offboard @username from blog
    /jinx report weekly
    /jinx chapter-setup Berlin Germany
    /jinx help

Commands are parsed by
[`cmd_parse()`](https://rladies.github.io/jinx/reference/command_parse.md)
and dispatched by
[`cmd_execute()`](https://rladies.github.io/jinx/reference/command_execute.md):

``` r

library(jinx)

cmd <- cmd_parse("/jinx invite @octocat to website")
cmd
#> $action
#> [1] "invite"
#> $username
#> [1] "octocat"
#> $team
#> [1] "website"
```

## Modules

jinx is organized into modules, each handling a specific domain:

| Module | Functions |
|----|----|
| Team management | [`gt_invite()`](https://rladies.github.io/jinx/reference/global_team_invite.md), [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/global_team_create_offboarding.md), [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_onboarding.md) |
| Announcements | [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md), [`post_bluesky()`](https://rladies.github.io/jinx/reference/post_bluesky.md), [`post_mastodon()`](https://rladies.github.io/jinx/reference/post_mastodon.md) |
| Directory | [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md), [`crop_directory_image()`](https://rladies.github.io/jinx/reference/crop_directory_image.md) |
| Blogs | [`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md), [`blog_check_links()`](https://rladies.github.io/jinx/reference/blog_check_links.md) |
| Chapters | [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md), [`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md) |
| Reports | [`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md), [`report_publish()`](https://rladies.github.io/jinx/reference/report_publish.md) |
| PR review | [`review_pr()`](https://rladies.github.io/jinx/reference/review_pr.md), [`check_pr_naming()`](https://rladies.github.io/jinx/reference/check_pr_naming.md) |
| Airtable sync | [`sync_directory_airtable()`](https://rladies.github.io/jinx/reference/sync_directory_airtable.md), [`sync_gt_airtable()`](https://rladies.github.io/jinx/reference/sync_global_team_airtable.md) |
| Website | [`website_merge_pending()`](https://rladies.github.io/jinx/reference/website_merge_pending.md), [`greet_contributor()`](https://rladies.github.io/jinx/reference/greet_contributor.md) |
| Chapter monitoring | [`monitor_chapter_status()`](https://rladies.github.io/jinx/reference/monitor_chapter_status.md), [`prepare_inactivity_emails()`](https://rladies.github.io/jinx/reference/prepare_inactivity_emails.md) |
| Slack | [`slack_invites_send()`](https://rladies.github.io/jinx/reference/slack_invites_send.md), [`subscribe_slack_rss()`](https://rladies.github.io/jinx/reference/subscribe_slack_rss.md) |
| GHA dashboard | [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md), [`gha_publish_dashboard()`](https://rladies.github.io/jinx/reference/gha_publish_dashboard.md) |
| Contributors | [`list_contributors()`](https://rladies.github.io/jinx/reference/list_contributors.md), [`contributors_update()`](https://rladies.github.io/jinx/reference/contributors_update.md) |

## Configuration

jinx loads configuration from YAML files in `inst/config/`:

``` r

config <- load_teams_config()
names(config$teams)
#>  [1] "abstract-review"    "blog"               "campaigns"
#>  [4] "chapter-activity"   "chapter-onboarding" "coc"
#>  [7] "communications"     "community-slack"    "conference-liaison"
#> [10] "directory"          "meetup-pro"         "mentoring"
#> [13] "rocur"              "translation"        "website"
```

- `teams.yml` – team definitions with roles, repos, notification
  channels
- `review-rules.yml` – PR review assignment and labeling rules
- `labels.yml` – file path to label mappings

## Template system

Templates live in `inst/templates/` as markdown files with `<KEY>`
placeholders. Team-specific extras live in `inst/templates/teams/`:

    inst/templates/
      global-team-onboarding.md      # Base onboarding template
      global-team-offboarding.md     # Base offboarding template
      chapter-setup.md               # Chapter setup checklist
      teams/
        website.md                   # Website team extras
        blog.md                      # Blog team extras
        ...

Templates are rendered via `render_template()` which replaces `<KEY>`
placeholders with values from a named list.

## Cross-repo PR review

Add this workflow to any RLadies+ repo for automated PR review:

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

## Next steps

See
[`vignette("workflows")`](https://rladies.github.io/jinx/articles/workflows.md)
for step-by-step guides for each admin workflow.
