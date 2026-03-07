# Workflow Reference for R-Ladies Org Admins

This vignette walks through each admin workflow jinx supports. For setup
and architecture details, see
[`vignette("getting-started")`](https://rladies.github.io/jinx/articles/getting-started.md).

## Onboarding a new team member

**Via issue comment:**

    /jinx invite @username to website

**What happens:**

1.  [`gt_invite()`](https://rladies.github.io/jinx/reference/gt_invite.md)
    sends an org invitation to the user
2.  A tracking issue is created with the team-specific onboarding
    checklist
3.  Once the user accepts,
    [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_onboarding.md)
    adds them to the appropriate team(s) and repos
4.  The tracking issue is closed

**Programmatically:**

``` r
gt_invite("octocat", "website")
```

**Checking pending invitations:**

``` r
gt_check_invitations()
```

## Offboarding a team member

**Via issue comment:**

    /jinx offboard @username from blog

**What happens:**

1.  [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/gt_create_offboarding.md)
    opens an offboarding tracking issue
2.  The issue lists cleanup steps (remove from team, repos, external
    services)
3.  Once complete,
    [`gt_finalize_offboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_offboarding.md)
    removes org access and closes the issue

**Programmatically:**

``` r
gt_create_offboarding("octocat", "blog")
```

## Setting up a new chapter

**Via issue comment:**

    /jinx chapter-setup Berlin Germany

**What happens:**

1.  [`create_chapter_setup()`](https://rladies.github.io/jinx/reference/create_chapter_setup.md)
    opens a setup tracking issue
2.  The issue contains a checklist: create repos, add organizers,
    configure Meetup, set up social media
3.  [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md)
    generates the chapter JSON for the directory
4.  [`create_chapter_json_pr()`](https://rladies.github.io/jinx/reference/create_chapter_json_pr.md)
    opens a PR to add the chapter to the directory

**Updating an existing chapter:**

    /jinx chapter-update Berlin Germany

## Monitoring chapter health

**Scheduled workflow** runs periodically via
[`check_chapter_health()`](https://rladies.github.io/jinx/reference/check_chapter_health.md).

**Via issue comment:**

    /jinx chapter-health

**What happens:**

1.  Reads chapter activity data (commits, issues, events)
2.  Classifies chapters as active, quiet, or inactive
3.  Posts a summary with recommendations

**Outreach to inactive chapters:**

``` r
statuses <- monitor_chapter_status()
prepare_inactivity_emails(statuses)
```

## Blog post workflow

### Adding a new blog entry

**Via issue comment:**

    /jinx blog-add https://example.com/my-rladies-post

**What happens:**

1.  [`create_blog_entry()`](https://rladies.github.io/jinx/reference/create_blog_entry.md)
    fetches metadata from the URL
2.  Creates a YAML entry and opens a PR to the blog repo
3.  [`post_blog_checklist()`](https://rladies.github.io/jinx/reference/post_blog_checklist.md)
    adds a review checklist to the PR

### Checking blog links

    /jinx blog-check-links

Runs
[`check_blog_links()`](https://rladies.github.io/jinx/reference/check_blog_links.md)
to find broken URLs across all blog entries.

### Auto-merge on publish date

[`auto_merge_pending()`](https://rladies.github.io/jinx/reference/auto_merge_pending.md)
runs on a schedule and merges blog PRs whose publish date has arrived.
This is triggered by the `website-merge-pending.yml` workflow.

## Announcing blog posts

After a blog post merges, announce it across platforms:

**Via issue comment:**

    /jinx announce https://rladies.org/blog/my-post/

**What happens:**

1.  [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
    reads the post’s YAML front matter
2.  [`create_announcement_message()`](https://rladies.github.io/jinx/reference/create_announcement_message.md)
    builds the message with hashtags
3.  Posts to Bluesky
    ([`post_bluesky()`](https://rladies.github.io/jinx/reference/post_bluesky.md)),
    Mastodon
    ([`post_mastodon()`](https://rladies.github.io/jinx/reference/post_mastodon.md)),
    LinkedIn
    ([`li_post_write()`](https://rladies.github.io/jinx/reference/li_post_write.md)),
    and newsletter
    ([`send_newsletter()`](https://rladies.github.io/jinx/reference/send_newsletter.md))

Each platform is posted independently – failures on one do not block
others.

## Running reports

### Activity reports

**Via issue comment:**

    /jinx report weekly
    /jinx report monthly

**Programmatically:**

``` r
report <- generate_report(type = "weekly")
publish_report(report)
```

### Chapter health reports

    /jinx report chapters

``` r
url <- report_chapter_health()
```

## Managing the GHA dashboard

    /jinx gha-dashboard

**What happens:**

1.  [`generate_gha_dashboard()`](https://rladies.github.io/jinx/reference/generate_gha_dashboard.md)
    queries workflow run status across all org repos
2.  [`publish_gha_dashboard()`](https://rladies.github.io/jinx/reference/publish_gha_dashboard.md)
    posts a formatted status table as a GitHub issue

**Scheduled workflow** runs weekly via `gha-dashboard.yml`.

## Airtable sync

**Scheduled workflow** runs weekly via `airtable-sync.yml`.

**Programmatically:**

``` r
sync_directory_airtable()
sync_global_team_airtable()
```

Syncs directory entries and global team data between Airtable and
GitHub. Creates PRs for any changes detected.

## Slack onboarding

``` r
send_slack_invites(dry_run = TRUE)
```

Fetches pending invitees from Airtable and sends Slack workspace
invitations. Use `dry_run = TRUE` (the default) to preview before
sending.

**RSS feed integration:**

``` r
subscribe_slack_rss()
```

Subscribes Slack channels to the R-Ladies blog RSS feed.

## Directory maintenance

**Validating directory PRs:**

The
[`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
function runs automatically on PRs that modify directory entries. It
checks:

- YAML schema compliance
- Filename conventions
  ([`validate_entry_filename()`](https://rladies.github.io/jinx/reference/validate_entry_filename.md))
- Image optimization
  ([`crop_directory_image()`](https://rladies.github.io/jinx/reference/crop_directory_image.md),
  [`optimize_image()`](https://rladies.github.io/jinx/reference/optimize_image.md))
- Social handle verification
  ([`verify_social_handles()`](https://rladies.github.io/jinx/reference/verify_social_handles.md))

## Contributor recognition

**List contributors for a repo:**

    /jinx contributors jinx

**Update the contributors list:**

    /jinx contributors update jinx

**Org-wide contributor stats:**

    /jinx contributors org

**Automated greetings:**

- [`welcome_contributor()`](https://rladies.github.io/jinx/reference/welcome_contributor.md)
  posts a welcome comment on first-time PRs
- [`thank_contributor()`](https://rladies.github.io/jinx/reference/thank_contributor.md)
  posts a thank-you when PRs are merged

Both are triggered by the `welcome-contributor.yml` and
`thank-contributor.yml` workflows.

## PR review automation

PR review runs automatically on pull requests via reusable workflows.

**What happens:**

1.  [`review_pr()`](https://rladies.github.io/jinx/reference/review_pr.md)
    applies the rules from `review-rules.yml`
2.  Reviewers are assigned based on file paths and team ownership
3.  Labels are applied based on `labels.yml` mappings
4.  [`check_pr_naming()`](https://rladies.github.io/jinx/reference/check_pr_naming.md)
    enforces branch and title conventions

**See**
[`vignette("getting-started")`](https://rladies.github.io/jinx/articles/getting-started.md)
for how to add PR review to other repos.

## Stale issue reminders

    /jinx remind stale

[`gt_remind_stale()`](https://rladies.github.io/jinx/reference/gt_remind_stale.md)
scans for onboarding/offboarding issues that have gone stale and posts
reminder comments.
