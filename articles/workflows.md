# Workflow Reference for RLadies+ Org Admins

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

1.  [`chapter_create_setup()`](https://rladies.github.io/jinx/reference/chapter_create_setup.md)
    opens a setup tracking issue
2.  The issue contains a checklist: create repos, add organizers,
    configure Meetup, set up social media
3.  [`chapter_create()`](https://rladies.github.io/jinx/reference/chapter_create.md)
    generates the chapter JSON for the directory
4.  [`chapter_create_pr()`](https://rladies.github.io/jinx/reference/chapter_create_pr.md)
    opens a PR to add the chapter to the directory

**Updating an existing chapter:**

    /jinx chapter-update Berlin Germany

## Monitoring chapter health

**Scheduled workflow** runs periodically via
[`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md).

**Via issue comment:**

    /jinx chapter-health

**What happens:**

1.  Reads chapter activity data (commits, issues, events)
2.  Classifies chapters as active, quiet, or inactive
3.  Posts a summary with recommendations

**Outreach to inactive chapters:**

``` r

statuses <- chapter_monitor_status()
prepare_inactivity_emails(statuses)
```

## Blog post workflow

### Adding a new blog entry

**Via issue comment:**

    /jinx blog-add https://example.com/my-rladies-post

**What happens:**

1.  [`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md)
    fetches metadata from the URL
2.  Creates a YAML entry and opens a PR to the blog repo
3.  [`blog_post_checklist()`](https://rladies.github.io/jinx/reference/blog_post_checklist.md)
    adds a review checklist to the PR

### Checking blog links

    /jinx blog-check-links

Runs
[`blog_check_links()`](https://rladies.github.io/jinx/reference/blog_check_links.md)
to find broken URLs across all blog entries.

### Auto-merge on publish date

[`website_merge_pending()`](https://rladies.github.io/jinx/reference/website_merge_pending.md)
runs on a schedule and merges blog PRs whose publish date has arrived.
This is triggered by the `website-merge-pending.yml` workflow.

## Announcing blog posts

After a blog post merges, announce it across platforms:

**Via issue comment:**

    /jinx announce https://rladies.org/blog/my-post/

**What happens:**

1.  [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
    reads the post’s YAML front matter
2.  [`announce_create_message()`](https://rladies.github.io/jinx/reference/announce_create_message.md)
    builds the message with hashtags
3.  Posts to Bluesky
    ([`announce_post_bluesky()`](https://rladies.github.io/jinx/reference/announce_post_bluesky.md)),
    Mastodon
    ([`announce_post_mastodon()`](https://rladies.github.io/jinx/reference/announce_post_mastodon.md)),
    LinkedIn
    ([`li_post_write()`](https://rladies.github.io/jinx/reference/li_post_write.md)),
    and newsletter
    ([`announce_send_newsletter()`](https://rladies.github.io/jinx/reference/announce_send_newsletter.md))

Each platform is posted independently – failures on one do not block
others.

## Running reports

### Activity reports

**Via issue comment:**

    /jinx report weekly
    /jinx report monthly

**Programmatically:**

``` r

report <- report_generate(type = "weekly")
report_publish(report)
```

### Chapter health reports

    /jinx report chapters

``` r

url <- chapter_report_health()
```

## Managing the GHA dashboard

    /jinx gha-dashboard

**What happens:**

1.  [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md)
    queries workflow run status across all org repos
2.  [`gha_publish_dashboard()`](https://rladies.github.io/jinx/reference/gha_publish_dashboard.md)
    posts a formatted status table as a GitHub issue

**Scheduled workflow** runs weekly via `gha-dashboard.yml`.

## Airtable sync

**Scheduled workflow** runs weekly via `airtable-sync.yml`.

**Programmatically:**

``` r

directory_sync_airtable()
gt_sync_airtable()
```

Syncs directory entries and global team data between Airtable and
GitHub. Creates PRs for any changes detected.

## Slack onboarding

``` r

slack_invite_batch(dry_run = TRUE)
```

Fetches pending invitees from Airtable and sends Slack workspace
invitations. Use `dry_run = TRUE` (the default) to preview before
sending.

**RSS feed integration:**

``` r

slack_subscribe_rss()
```

Subscribes Slack channels to the RLadies+ blog RSS feed.

## Directory maintenance

**Validating directory PRs:**

The
[`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
function runs automatically on PRs that modify directory entries. It
checks:

- YAML schema compliance
- Filename conventions
  ([`directory_validate_filename()`](https://rladies.github.io/jinx/reference/directory_validate_filename.md))
- Image optimization
  ([`directory_crop_image()`](https://rladies.github.io/jinx/reference/directory_crop_image.md),
  [`directory_optimize_image()`](https://rladies.github.io/jinx/reference/directory_optimize_image.md))
- Social handle verification
  ([`directory_verify_handles()`](https://rladies.github.io/jinx/reference/directory_verify_handles.md))

## Contributor recognition

**List contributors for a repo:**

    /jinx contributors jinx

**Update the contributors list:**

    /jinx contributors update jinx

**Org-wide contributor stats:**

    /jinx contributors org

**Automated greetings:**

- [`contributor_welcome()`](https://rladies.github.io/jinx/reference/contributor_welcome.md)
  posts a welcome comment on first-time PRs
- [`contributor_thank()`](https://rladies.github.io/jinx/reference/contributor_thank.md)
  posts a thank-you when PRs are merged

Both are triggered by the `welcome-contributor.yml` and
`thank-contributor.yml` workflows.

## PR review automation

PR review runs automatically on pull requests via reusable workflows.

**What happens:**

1.  [`review_run()`](https://rladies.github.io/jinx/reference/review_run.md)
    applies the rules from `review-rules.yml`
2.  Reviewers are assigned based on file paths and team ownership
3.  Labels are applied based on `labels.yml` mappings
4.  [`review_check_pr_naming()`](https://rladies.github.io/jinx/reference/review_check_pr_naming.md)
    enforces branch and title conventions

**See**
[`vignette("getting-started")`](https://rladies.github.io/jinx/articles/getting-started.md)
for how to add PR review to other repos.

## Stale issue reminders

    /jinx remind stale

[`gt_remind_stale()`](https://rladies.github.io/jinx/reference/gt_remind_stale.md)
scans for onboarding/offboarding issues that have gone stale and posts
reminder comments.
