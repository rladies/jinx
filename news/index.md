# Changelog

## jinx 0.1.0

Initial release of the jinx R package for R-Ladies GitHub organization
management.

### Team management

- [`gt_invite()`](https://rladies.github.io/jinx/reference/gt_invite.md),
  [`gt_check_invitations()`](https://rladies.github.io/jinx/reference/gt_check_invitations.md),
  [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_onboarding.md)
  for onboarding new global team members.
- [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/gt_create_offboarding.md),
  [`gt_finalize_offboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_offboarding.md)
  for offboarding.
- [`gt_remind_stale()`](https://rladies.github.io/jinx/reference/gt_remind_stale.md)
  for stale issue reminders.

### Announcements

- [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
  cross-posts blog announcements to Bluesky, LinkedIn, Mastodon, and
  newsletter.
- Platform integrations:
  [`post_bluesky()`](https://rladies.github.io/jinx/reference/post_bluesky.md),
  [`post_mastodon()`](https://rladies.github.io/jinx/reference/post_mastodon.md),
  [`li_post_write()`](https://rladies.github.io/jinx/reference/li_post_write.md),
  [`send_newsletter()`](https://rladies.github.io/jinx/reference/send_newsletter.md).
- Utilities:
  [`create_announcement_message()`](https://rladies.github.io/jinx/reference/create_announcement_message.md),
  [`short_url()`](https://rladies.github.io/jinx/reference/short_url.md),
  [`tags2hash()`](https://rladies.github.io/jinx/reference/tags2hash.md),
  [`random_emoji()`](https://rladies.github.io/jinx/reference/random_emoji.md).

### Directory

- [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md),
  [`validate_directory_entries()`](https://rladies.github.io/jinx/reference/validate_directory_entries.md),
  [`validate_entry_filename()`](https://rladies.github.io/jinx/reference/validate_entry_filename.md)
  for directory entry validation.
- [`verify_social_handles()`](https://rladies.github.io/jinx/reference/verify_social_handles.md)
  for social media handle verification.
- [`crop_directory_image()`](https://rladies.github.io/jinx/reference/crop_directory_image.md),
  [`optimize_image()`](https://rladies.github.io/jinx/reference/optimize_image.md)
  for image processing.

### Blogs

- [`create_blog_entry()`](https://rladies.github.io/jinx/reference/create_blog_entry.md),
  [`validate_blog_entry()`](https://rladies.github.io/jinx/reference/validate_blog_entry.md)
  for blog content management.
- [`check_blog_links()`](https://rladies.github.io/jinx/reference/check_blog_links.md)
  for link validation.
- [`post_blog_checklist()`](https://rladies.github.io/jinx/reference/post_blog_checklist.md)
  for automated PR review checklists.

### Chapters

- [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md),
  [`create_chapter_setup()`](https://rladies.github.io/jinx/reference/create_chapter_setup.md),
  [`create_chapter_update()`](https://rladies.github.io/jinx/reference/create_chapter_update.md)
  for chapter lifecycle management.
- [`create_chapter_json_pr()`](https://rladies.github.io/jinx/reference/create_chapter_json_pr.md)
  for directory integration.
- [`check_chapter_health()`](https://rladies.github.io/jinx/reference/check_chapter_health.md)
  for activity monitoring.

### Reports

- [`generate_report()`](https://rladies.github.io/jinx/reference/generate_report.md),
  [`publish_report()`](https://rladies.github.io/jinx/reference/publish_report.md)
  for activity reports.
- [`report_chapter_health()`](https://rladies.github.io/jinx/reference/report_chapter_health.md)
  for chapter-specific reporting.
- [`format_report_markdown()`](https://rladies.github.io/jinx/reference/format_report_markdown.md)
  for report rendering.

### PR review

- [`review_pr()`](https://rladies.github.io/jinx/reference/review_pr.md),
  [`check_pr_naming()`](https://rladies.github.io/jinx/reference/check_pr_naming.md)
  for automated PR review.
- Configurable rules via `inst/config/review-rules.yml`.

### Airtable sync

- [`sync_directory_airtable()`](https://rladies.github.io/jinx/reference/sync_directory_airtable.md),
  [`sync_global_team_airtable()`](https://rladies.github.io/jinx/reference/sync_global_team_airtable.md)
  for bidirectional sync between Airtable and GitHub.

### Website automation

- [`auto_merge_pending()`](https://rladies.github.io/jinx/reference/auto_merge_pending.md)
  for date-based PR auto-merge.
- [`greet_contributor()`](https://rladies.github.io/jinx/reference/greet_contributor.md)
  for contributor interaction.

### Chapter monitoring

- [`monitor_chapter_status()`](https://rladies.github.io/jinx/reference/monitor_chapter_status.md)
  for activity classification.
- [`prepare_inactivity_emails()`](https://rladies.github.io/jinx/reference/prepare_inactivity_emails.md)
  for outreach to inactive chapters.

### Slack management

- [`send_slack_invites()`](https://rladies.github.io/jinx/reference/send_slack_invites.md)
  for community Slack onboarding.
- [`subscribe_slack_rss()`](https://rladies.github.io/jinx/reference/subscribe_slack_rss.md)
  for blog feed integration.
- [`welcome_slack_member()`](https://rladies.github.io/jinx/reference/welcome_slack_member.md)
  sends a workspace-aware welcome DM to a new member, with separate
  templates for the RLadies+ community and organisers Slack workspaces.
  Stateless: triggered by a Slack `team_join` event via the
  `slack-welcome.yml` workflow (`workflow_dispatch` /
  `repository_dispatch`) — jinx does not persist any user identifiers.

### GHA dashboard

- [`generate_gha_dashboard()`](https://rladies.github.io/jinx/reference/generate_gha_dashboard.md),
  [`publish_gha_dashboard()`](https://rladies.github.io/jinx/reference/publish_gha_dashboard.md)
  for org-wide GitHub Actions workflow status reporting.

### Contributors

- [`list_contributors()`](https://rladies.github.io/jinx/reference/list_contributors.md),
  [`list_org_contributors()`](https://rladies.github.io/jinx/reference/list_org_contributors.md)
  for contributor tracking.
- [`format_contributors()`](https://rladies.github.io/jinx/reference/format_contributors.md),
  [`update_contributors_list()`](https://rladies.github.io/jinx/reference/update_contributors_list.md)
  for display and maintenance.
- [`welcome_contributor()`](https://rladies.github.io/jinx/reference/welcome_contributor.md),
  [`thank_contributor()`](https://rladies.github.io/jinx/reference/thank_contributor.md)
  for automated greetings.

### Commands

- `/jinx` issue comment interface via
  [`parse_command()`](https://rladies.github.io/jinx/reference/parse_command.md)
  and
  [`execute_command()`](https://rladies.github.io/jinx/reference/execute_command.md).
- 16 commands: invite, offboard, announce, validate-directory,
  chapter-health, blog-add, blog-check-links, report, chapter-setup,
  chapter-update, gha-dashboard, contributors, remind, help.

### Event management

- [`list_chapter_events()`](https://rladies.github.io/jinx/reference/list_chapter_events.md)
  queries Meetup Pro for chapter events.
- [`sync_chapter_events()`](https://rladies.github.io/jinx/reference/sync_chapter_events.md)
  fetches events across all configured chapters.
- [`create_event_summary()`](https://rladies.github.io/jinx/reference/create_event_summary.md),
  [`publish_event_summary()`](https://rladies.github.io/jinx/reference/publish_event_summary.md)
  for reporting.
- Meetup GraphQL API integration via Meetup Pro.

### Analytics dashboard

- [`collect_chapter_activity()`](https://rladies.github.io/jinx/reference/collect_chapter_activity.md),
  [`collect_contributor_growth()`](https://rladies.github.io/jinx/reference/collect_contributor_growth.md)
  for data collection.
- [`compute_activity_trends()`](https://rladies.github.io/jinx/reference/compute_activity_trends.md)
  with ASCII sparklines for trend visualization.
- [`generate_analytics_dashboard()`](https://rladies.github.io/jinx/reference/generate_analytics_dashboard.md),
  [`publish_analytics_dashboard()`](https://rladies.github.io/jinx/reference/publish_analytics_dashboard.md)
  for monthly org-wide analytics.

### Website analytics

- [`collect_website_analytics()`](https://rladies.github.io/jinx/reference/collect_website_analytics.md)
  fetches visitor, pageview, and engagement metrics from Plausible
  Analytics API.
- [`format_website_analytics()`](https://rladies.github.io/jinx/reference/format_website_analytics.md)
  renders analytics as markdown with traffic trends, top pages, and
  referral sources.
- [`generate_website_report()`](https://rladies.github.io/jinx/reference/generate_website_report.md),
  [`publish_website_report()`](https://rladies.github.io/jinx/reference/publish_website_report.md)
  for periodic website performance reports.
- `/jinx website-analytics [period]` command with configurable time
  periods.

### Conference coordination

- [`list_open_cfps()`](https://rladies.github.io/jinx/reference/list_open_cfps.md),
  [`create_cfp_issue()`](https://rladies.github.io/jinx/reference/create_cfp_issue.md),
  [`check_cfp_deadlines()`](https://rladies.github.io/jinx/reference/check_cfp_deadlines.md)
  for CFP tracking via GitHub Issues.
- [`recommend_speaker()`](https://rladies.github.io/jinx/reference/recommend_speaker.md),
  [`list_speaker_recommendations()`](https://rladies.github.io/jinx/reference/list_speaker_recommendations.md)
  for speaker management.
- [`generate_conference_report()`](https://rladies.github.io/jinx/reference/generate_conference_report.md)
  for coordination summaries.

### Internationalization

- [`translate_template()`](https://rladies.github.io/jinx/reference/translate_template.md)
  with automatic fallback to English.
- [`list_supported_languages()`](https://rladies.github.io/jinx/reference/list_supported_languages.md),
  [`get_chapter_language()`](https://rladies.github.io/jinx/reference/get_chapter_language.md)
  for language management.
- [`validate_translations()`](https://rladies.github.io/jinx/reference/validate_translations.md),
  [`check_translation_coverage()`](https://rladies.github.io/jinx/reference/check_translation_coverage.md)
  for translation quality assurance.
- Starter translations for Spanish, Portuguese, and French.

### Infrastructure

- ROR identifier for R-Ladies Global (`https://ror.org/05wpb1k41`).
- 24 GitHub Actions workflows for automated operations.
- JSON schemas for directory entries, blog entries, chapters, team data,
  events, and CFPs.
- Template system with team-specific extras and i18n support.
- pkgdown documentation site at `https://rladies.github.io/jinx/`.
- Getting Started and Workflow Reference vignettes.
