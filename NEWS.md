# jinx 0.1.0

Initial release of the jinx R package for R-Ladies GitHub organization
management.

## Team management

- `global_team_invite()`, `global_team_check_invitations()`, `global_team_finalize_onboarding()` for
  onboarding new global team members.
- `global_team_create_offboarding()`, `global_team_finalize_offboarding()` for offboarding.
- `global_team_remind_stale()` for stale issue reminders.

## Announcements

- `announce_post()` cross-posts blog announcements to Bluesky, LinkedIn,
  Mastodon, and newsletter.
- Platform integrations: `post_bluesky()`, `post_mastodon()`,
  `li_post_write()`, `send_newsletter()`.
- Utilities: `create_announcement_message()`, `short_url()`, `tags2hash()`,
  `random_emoji()`.

## Directory

- `validate_directory_pr()`, `validate_directory_entries()`,
  `validate_entry_filename()` for directory entry validation.
- `verify_social_handles()` for social media handle verification.
- `crop_directory_image()`, `optimize_image()` for image processing.

## Blogs

- `blog_create_entry()`, `validate_blog_entry()` for blog content management.
- `blog_check_links()` for link validation.
- `blog_post_checklist()` for automated PR review checklists.

## Chapters

- `create_chapter()`, `chapter_create_setup()`, `chapter_create_update()` for
  chapter lifecycle management.
- `create_chapter_json_pr()` for directory integration.
- `chapter_check_health()` for activity monitoring.

## Reports

- `report_generate()`, `report_publish()` for activity reports.
- `chapter_report_health()` for chapter-specific reporting.
- `report_format_markdown()` for report rendering.

## PR review

- `review_pr()`, `check_pr_naming()` for automated PR review.
- Configurable rules via `inst/config/review-rules.yml`.

## Airtable sync

- `sync_directory_airtable()`, `sync_global_team_airtable()` for
  bidirectional sync between Airtable and GitHub.

## Website automation

- `website_merge_pending()` for date-based PR auto-merge.
- `greet_contributor()` for contributor interaction.

## Chapter monitoring

- `monitor_chapter_status()` for activity classification.
- `prepare_inactivity_emails()` for outreach to inactive chapters.

## Slack management

- `slack_invites_send()` for community Slack onboarding.
- `subscribe_slack_rss()` for blog feed integration.
- `slack_welcome_member()` sends a workspace-aware welcome DM to a new
  member, with separate templates for the RLadies+ community and
  organisers Slack workspaces. Stateless: triggered by a Slack
  `team_join` event via the `slack-welcome.yml` workflow
  (`workflow_dispatch` / `repository_dispatch`) — jinx does not
  persist any user identifiers.

## GHA dashboard

- `gha_generate_dashboard()`, `gha_publish_dashboard()` for org-wide
  GitHub Actions workflow status reporting.

## Contributors

- `list_contributors()`, `list_org_contributors()` for contributor tracking.
- `format_contributors()`, `contributors_update()` for display and
  maintenance.
- `contributor_welcome()`, `contributor_thank()` for automated greetings.

## Commands

- `/jinx` issue comment interface via `command_parse()` and
  `command_execute()`.
- 16 commands: invite, offboard, announce, validate-directory, chapter-health,
  blog-add, blog-check-links, report, chapter-setup, chapter-update,
  gha-dashboard, contributors, remind, help.

## Event management

- `events_list_chapter()` queries Meetup Pro for chapter events.
- `events_sync_chapters()` fetches events across all configured chapters.
- `events_create_summary()`, `events_publish_summary()` for reporting.
- Meetup GraphQL API integration via Meetup Pro.

## Analytics dashboard

- `collect_chapter_activity()`, `collect_contributor_growth()` for data
  collection.
- `compute_activity_trends()` with ASCII sparklines for trend visualization.
- `analytics_generate_dashboard()`, `analytics_publish_dashboard()` for
  monthly org-wide analytics.

## Website analytics

- `collect_website_analytics()` fetches visitor, pageview, and engagement
  metrics from Plausible Analytics API.
- `format_website_analytics()` renders analytics as markdown with traffic
  trends, top pages, and referral sources.
- `generate_website_report()`, `publish_website_report()` for periodic
  website performance reports.
- `/jinx website-analytics [period]` command with configurable time periods.

## Conference coordination

- `cfp_list_open()`, `cfp_create_issue()`, `cfp_check_deadlines()` for
  CFP tracking via GitHub Issues.
- `cfp_recommend_speaker()`, `list_speaker_recommendations()` for speaker
  management.
- `generate_conference_report()` for coordination summaries.

## Internationalization

- `translate_template()` with automatic fallback to English.
- `list_supported_languages()`, `get_chapter_language()` for language
  management.
- `i18n_translations_validate()`, `i18n_coverage_check()` for
  translation quality assurance.
- Starter translations for Spanish, Portuguese, and French.

## Infrastructure

- ROR identifier for R-Ladies Global (`https://ror.org/05wpb1k41`).
- 24 GitHub Actions workflows for automated operations.
- JSON schemas for directory entries, blog entries, chapters, team data,
  events, and CFPs.
- Template system with team-specific extras and i18n support.
- pkgdown documentation site at `https://rladies.github.io/jinx/`.
- Getting Started and Workflow Reference vignettes.
