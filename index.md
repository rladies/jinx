# jinx

R-Ladies GitHub organization management bot. An R package deployed via
GitHub Actions with a registered GitHub App identity (`jinx[bot]`).

## Features

- **Onboarding/Offboarding** - Automate adding/removing global team
  members across org repos
- **PR Review Automation** - Auto-assign reviewers, label PRs, enforce
  conventions
- **Report Generation** - Org-wide activity and health reports
- **Issue Commands** - Interactive `/jinx` commands in issue comments

## Commands

Use these in any issue comment in a repo where jinx is installed:

| Command                            | Description                          |
|------------------------------------|--------------------------------------|
| `/jinx invite @user to <team>`     | Invite a user to the org and a team  |
| `/jinx offboard @user from <team>` | Start offboarding a user from a team |
| `/jinx report weekly\|monthly`     | Generate an activity report          |
| `/jinx remind stale`               | Send reminders on stale issues       |
| `/jinx help`                       | Show help message                    |

## Teams

abstract-review, blog, campaigns, chapter-activity, chapter-onboarding,
coc, communications, community-slack, conference-liaison, directory,
meetup-pro, mentoring, rocur, translation, website

## Setup

### 1. Register the GitHub App

1.  Go to
    [github.com/organizations/rladies/settings/apps/new](https://github.com/organizations/rladies/settings/apps/new)
2.  Name: `jinx`
3.  Permissions:
    - Repository: Issues (R/W), Pull Requests (R/W), Contents (Read)
    - Organization: Members (R/W), Administration (Read)
4.  Events: `issue_comment`, `issues`, `pull_request`
5.  Install on the R-Ladies org

### 2. Configure secrets

In the jinx repo (or org-wide):

- **Variable** `JINX_APP_ID` - The GitHub App’s ID
- **Secret** `JINX_PRIVATE_KEY` - The GitHub App’s private key

### 3. Cross-repo PR review

Add this workflow to any R-Ladies repo that wants PR review automation:

``` yaml
# .github/workflows/jinx-review.yml
name: PR Review
on:
  pull_request:
    types: [opened, reopened, synchronize]
jobs:
  review:
    uses: rladies/jinx/.github/workflows/pr-review.yml@main
    secrets: inherit
```

## Development

``` r
# Install dependencies
install.packages(c("gh", "yaml", "cli", "glue", "testthat", "httptest2", "withr"))

# Run tests
devtools::test()

# Check package
devtools::check()
```

## Architecture

jinx is a standard R package. GitHub Actions workflows call exported R
functions. The `gh` package handles GitHub API authentication
automatically via the `GITHUB_TOKEN` environment variable. When using a
GitHub App token (via `actions/create-github-app-token`), API calls and
comments appear as `jinx[bot]`.

    Issue comment (/jinx invite ...)
      → issue_comment workflow triggers
        → installs jinx R package
          → calls jinx::parse_command() + jinx::execute_command()
            → gh::gh() API calls as jinx[bot]
              → reply comment posted
