# Changelog

## jinx 0.1.0

Initial release of the jinx R package for RLadies+ GitHub organization
management.

### Team management

- [`global_team_invite()`](https://rladies.github.io/jinx/reference/global_team_invite.md),
  [`global_team_check_invitations()`](https://rladies.github.io/jinx/reference/global_team_check_invitations.md),
  [`global_team_finalize_onboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_onboarding.md)
  for onboarding new global team members.
- [`global_team_create_offboarding()`](https://rladies.github.io/jinx/reference/global_team_create_offboarding.md),
  [`global_team_finalize_offboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_offboarding.md)
  for offboarding.
- [`global_team_remind_stale()`](https://rladies.github.io/jinx/reference/global_team_remind_stale.md)
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

- [`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md),
  [`validate_blog_entry()`](https://rladies.github.io/jinx/reference/validate_blog_entry.md)
  for blog content management.
- [`blog_check_links()`](https://rladies.github.io/jinx/reference/blog_check_links.md)
  for link validation.
- [`blog_post_checklist()`](https://rladies.github.io/jinx/reference/blog_post_checklist.md)
  for automated PR review checklists.

### Chapters

- [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md),
  [`chapter_create_setup()`](https://rladies.github.io/jinx/reference/chapter_create_setup.md),
  [`chapter_create_update()`](https://rladies.github.io/jinx/reference/chapter_create_update.md)
  for chapter lifecycle management.
- [`create_chapter_json_pr()`](https://rladies.github.io/jinx/reference/create_chapter_json_pr.md)
  for directory integration.
- [`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md)
  for activity monitoring.

### Reports

- [`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md),
  [`report_publish()`](https://rladies.github.io/jinx/reference/report_publish.md)
  for activity reports.
- [`chapter_report_health()`](https://rladies.github.io/jinx/reference/chapter_report_health.md)
  for chapter-specific reporting.
- [`report_format_markdown()`](https://rladies.github.io/jinx/reference/report_format_markdown.md)
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

- [`website_merge_pending()`](https://rladies.github.io/jinx/reference/website_merge_pending.md)
  for date-based PR auto-merge.
- [`greet_contributor()`](https://rladies.github.io/jinx/reference/greet_contributor.md)
  for contributor interaction.

### Chapter monitoring

- [`monitor_chapter_status()`](https://rladies.github.io/jinx/reference/monitor_chapter_status.md)
  for activity classification.
- [`prepare_inactivity_emails()`](https://rladies.github.io/jinx/reference/prepare_inactivity_emails.md)
  for outreach to inactive chapters.

### Slack management

- [`slack_invites_send()`](https://rladies.github.io/jinx/reference/slack_invites_send.md)
  for community Slack onboarding.
- [`subscribe_slack_rss()`](https://rladies.github.io/jinx/reference/subscribe_slack_rss.md)
  for blog feed integration.
- [`slack_welcome_member()`](https://rladies.github.io/jinx/reference/slack_welcome_member.md)
  sends a workspace-aware welcome DM to a new member, with separate
  templates for the RLadies+ community and organisers Slack workspaces.
  Stateless: triggered by a Slack `team_join` event via the
  `slack-welcome.yml` workflow (`workflow_dispatch` /
  `repository_dispatch`) — jinx does not persist any user identifiers.

### GHA dashboard

- [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md),
  [`gha_publish_dashboard()`](https://rladies.github.io/jinx/reference/gha_publish_dashboard.md)
  for org-wide GitHub Actions workflow status reporting.

### Contributors

- [`list_contributors()`](https://rladies.github.io/jinx/reference/list_contributors.md),
  [`list_org_contributors()`](https://rladies.github.io/jinx/reference/list_org_contributors.md)
  for contributor tracking.
- [`format_contributors()`](https://rladies.github.io/jinx/reference/format_contributors.md),
  [`contributors_update()`](https://rladies.github.io/jinx/reference/contributors_update.md)
  for display and maintenance.
- [`contributor_welcome()`](https://rladies.github.io/jinx/reference/contributor_welcome.md),
  [`contributor_thank()`](https://rladies.github.io/jinx/reference/contributor_thank.md)
  for automated greetings.

### Commands

- `/jinx` issue comment interface via
  [`command_parse()`](https://rladies.github.io/jinx/reference/command_parse.md)
  and
  [`command_execute()`](https://rladies.github.io/jinx/reference/command_execute.md).
- 16 commands: invite, offboard, announce, validate-directory,
  chapter-health, blog-add, blog-check-links, report, chapter-setup,
  chapter-update, gha-dashboard, contributors, remind, help.

### Event management

- [`events_list_chapter()`](https://rladies.github.io/jinx/reference/events_list_chapter.md)
  queries Meetup Pro for chapter events.
- [`events_sync_chapters()`](https://rladies.github.io/jinx/reference/events_sync_chapters.md)
  fetches events across all configured chapters.
- [`events_create_summary()`](https://rladies.github.io/jinx/reference/events_create_summary.md),
  [`events_publish_summary()`](https://rladies.github.io/jinx/reference/events_publish_summary.md)
  for reporting.
- Meetup GraphQL API integration via Meetup Pro.

### Analytics dashboard

- [`collect_chapter_activity()`](https://rladies.github.io/jinx/reference/collect_chapter_activity.md),
  [`collect_contributor_growth()`](https://rladies.github.io/jinx/reference/collect_contributor_growth.md)
  for data collection.
- [`compute_activity_trends()`](https://rladies.github.io/jinx/reference/compute_activity_trends.md)
  with ASCII sparklines for trend visualization.
- [`analytics_generate_dashboard()`](https://rladies.github.io/jinx/reference/analytics_generate_dashboard.md),
  [`analytics_publish_dashboard()`](https://rladies.github.io/jinx/reference/analytics_publish_dashboard.md)
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

- [`cfp_list_open()`](https://rladies.github.io/jinx/reference/cfp_list_open.md),
  [`cfp_create_issue()`](https://rladies.github.io/jinx/reference/cfp_create_issue.md),
  [`cfp_check_deadlines()`](https://rladies.github.io/jinx/reference/cfp_check_deadlines.md)
  for CFP tracking via GitHub Issues.
- [`cfp_recommend_speaker()`](https://rladies.github.io/jinx/reference/cfp_recommend_speaker.md),
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
- [`i18n_translations_validate()`](https://rladies.github.io/jinx/reference/i18n_translations_validate.md),
  [`i18n_coverage_check()`](https://rladies.github.io/jinx/reference/i18n_coverage_check.md)
  for translation quality assurance.
- Starter translations for Spanish, Portuguese, and French.

### Infrastructure

- ROR identifier for RLadies+ Global (`https://ror.org/05wpb1k41`).
- 24 GitHub Actions workflows for automated operations.
- JSON schemas for directory entries, blog entries, chapters, team data,
  events, and CFPs.
- Template system with team-specific extras and i18n support.
- pkgdown documentation site at `https://rladies.github.io/jinx/`.
- Getting Started and Workflow Reference vignettes.
