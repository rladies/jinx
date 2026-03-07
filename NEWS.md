# jinx 0.1.0

Initial release of the jinx R package for R-Ladies GitHub organization
management.

## Team management

* `gt_invite()`, `gt_check_invitations()`, `gt_finalize_onboarding()` for
  onboarding new global team members.
* `gt_create_offboarding()`, `gt_finalize_offboarding()` for offboarding.
* `gt_remind_stale()` for stale issue reminders.

## Announcements

* `announce_post()` cross-posts blog announcements to Bluesky, LinkedIn,
  Mastodon, and newsletter.
* Platform integrations: `post_bluesky()`, `post_mastodon()`,
  `li_post_write()`, `send_newsletter()`.
* Utilities: `create_announcement_message()`, `short_url()`, `tags2hash()`,
  `random_emoji()`.

## Directory

* `validate_directory_pr()`, `validate_directory_entries()`,
  `validate_entry_filename()` for directory entry validation.
* `verify_social_handles()` for social media handle verification.
* `crop_directory_image()`, `optimize_image()` for image processing.

## Blogs

* `create_blog_entry()`, `validate_blog_entry()` for blog content management.
* `check_blog_links()` for link validation.
* `post_blog_checklist()` for automated PR review checklists.

## Chapters

* `create_chapter()`, `create_chapter_setup()`, `create_chapter_update()` for
  chapter lifecycle management.
* `create_chapter_json_pr()` for directory integration.
* `check_chapter_health()` for activity monitoring.

## Reports

* `generate_report()`, `publish_report()` for activity reports.
* `report_chapter_health()` for chapter-specific reporting.
* `format_report_markdown()` for report rendering.

## PR review

* `review_pr()`, `check_pr_naming()` for automated PR review.
* Configurable rules via `inst/config/review-rules.yml`.

## Airtable sync

* `sync_directory_airtable()`, `sync_global_team_airtable()` for
  bidirectional sync between Airtable and GitHub.

## Website automation

* `auto_merge_pending()` for date-based PR auto-merge.
* `greet_contributor()` for contributor interaction.

## Chapter monitoring

* `monitor_chapter_status()` for activity classification.
* `prepare_inactivity_emails()` for outreach to inactive chapters.

## Slack management

* `send_slack_invites()` for community Slack onboarding.
* `subscribe_slack_rss()` for blog feed integration.

## GHA dashboard

* `generate_gha_dashboard()`, `publish_gha_dashboard()` for org-wide
  GitHub Actions workflow status reporting.

## Contributors

* `list_contributors()`, `list_org_contributors()` for contributor tracking.
* `format_contributors()`, `update_contributors_list()` for display and
  maintenance.
* `welcome_contributor()`, `thank_contributor()` for automated greetings.

## Commands

* `/jinx` issue comment interface via `parse_command()` and
  `execute_command()`.
* 16 commands: invite, offboard, announce, validate-directory, chapter-health,
  blog-add, blog-check-links, report, chapter-setup, chapter-update,
  gha-dashboard, contributors, remind, help.

## Event management

* `list_chapter_events()` queries Meetup Pro for chapter events.
* `sync_chapter_events()` fetches events across all configured chapters.
* `create_event_summary()`, `publish_event_summary()` for reporting.
* Meetup GraphQL API integration via Meetup Pro.

## Analytics dashboard

* `collect_chapter_activity()`, `collect_contributor_growth()` for data
  collection.
* `compute_activity_trends()` with ASCII sparklines for trend visualization.
* `generate_analytics_dashboard()`, `publish_analytics_dashboard()` for
  monthly org-wide analytics.

## Conference coordination

* `list_open_cfps()`, `create_cfp_issue()`, `check_cfp_deadlines()` for
  CFP tracking via GitHub Issues.
* `recommend_speaker()`, `list_speaker_recommendations()` for speaker
  management.
* `generate_conference_report()` for coordination summaries.

## Internationalization

* `translate_template()` with automatic fallback to English.
* `list_supported_languages()`, `get_chapter_language()` for language
  management.
* `validate_translations()`, `check_translation_coverage()` for
  translation quality assurance.
* Starter translations for Spanish, Portuguese, and French.

## Infrastructure

* ROR identifier for R-Ladies Global (`https://ror.org/05wpb1k41`).
* 24 GitHub Actions workflows for automated operations.
* JSON schemas for directory entries, blog entries, chapters, team data,
  events, and CFPs.
* Template system with team-specific extras and i18n support.
* pkgdown documentation site at `https://rladies.github.io/jinx/`.
* Getting Started and Workflow Reference vignettes.
