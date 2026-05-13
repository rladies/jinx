# Package index

## Commands

Issue comment command interface

- [`command_execute()`](https://rladies.github.io/jinx/reference/command_execute.md)
  [`cmd_execute()`](https://rladies.github.io/jinx/reference/command_execute.md)
  : Execute a parsed jinx command
- [`command_parse()`](https://rladies.github.io/jinx/reference/command_parse.md)
  [`cmd_parse()`](https://rladies.github.io/jinx/reference/command_parse.md)
  : Parse a jinx command from an issue comment

## Team management

Global team onboarding and offboarding

- [`global_team_check_invitations()`](https://rladies.github.io/jinx/reference/global_team_check_invitations.md)
  [`gt_check_invitations()`](https://rladies.github.io/jinx/reference/global_team_check_invitations.md)
  : Check pending global team invitations
- [`global_team_create_offboarding()`](https://rladies.github.io/jinx/reference/global_team_create_offboarding.md)
  [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/global_team_create_offboarding.md)
  : Create a global team offboarding issue
- [`global_team_finalize_offboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_offboarding.md)
  [`gt_finalize_offboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_offboarding.md)
  : Finalize global team offboarding by removing user from teams
- [`global_team_finalize_onboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_onboarding.md)
  [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/global_team_finalize_onboarding.md)
  : Finalize global team onboarding for an accepted member
- [`global_team_invite()`](https://rladies.github.io/jinx/reference/global_team_invite.md)
  [`gt_invite()`](https://rladies.github.io/jinx/reference/global_team_invite.md)
  : Invite a user to the RLadies+ global team
- [`global_team_remind_stale()`](https://rladies.github.io/jinx/reference/global_team_remind_stale.md)
  [`gt_remind_stale()`](https://rladies.github.io/jinx/reference/global_team_remind_stale.md)
  : Send reminders on stale global team onboarding/offboarding issues

## Announcements

Cross-platform blog post announcements

- [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
  : Announce a blog post across multiple platforms
- [`create_announcement_message()`](https://rladies.github.io/jinx/reference/create_announcement_message.md)
  : Create a formatted announcement message
- [`post_bluesky()`](https://rladies.github.io/jinx/reference/post_bluesky.md)
  : Post an announcement to Bluesky
- [`post_mastodon()`](https://rladies.github.io/jinx/reference/post_mastodon.md)
  : Post an announcement to Mastodon
- [`li_post_write()`](https://rladies.github.io/jinx/reference/li_post_write.md)
  : Post to LinkedIn
- [`li_req()`](https://rladies.github.io/jinx/reference/li_req.md) :
  Create a base LinkedIn API request
- [`li_oauth()`](https://rladies.github.io/jinx/reference/li_oauth.md) :
  Perform LinkedIn OAuth authentication
- [`li_urn_me()`](https://rladies.github.io/jinx/reference/li_urn_me.md)
  : Get the LinkedIn URN for the authenticated user
- [`li_media_upload()`](https://rladies.github.io/jinx/reference/li_media_upload.md)
  : Upload media to LinkedIn
- [`li_get_version()`](https://rladies.github.io/jinx/reference/li_get_version.md)
  : Get LinkedIn API version string
- [`send_newsletter()`](https://rladies.github.io/jinx/reference/send_newsletter.md)
  : Send a newsletter via ConvertKit
- [`short_url()`](https://rladies.github.io/jinx/reference/short_url.md)
  : Shorten a URL using the Short.io API
- [`tags2hash()`](https://rladies.github.io/jinx/reference/tags2hash.md)
  : Convert tags to hashtag string
- [`random_emoji()`](https://rladies.github.io/jinx/reference/random_emoji.md)
  : Select a random emoji

## Directory

Directory entry management and validation

- [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
  : Post a directory validation report as a PR comment
- [`validate_directory_entries()`](https://rladies.github.io/jinx/reference/validate_directory_entries.md)
  : Validate directory entry JSON files against schema
- [`validate_entry_filename()`](https://rladies.github.io/jinx/reference/validate_entry_filename.md)
  : Validate a directory entry filename
- [`verify_social_handles()`](https://rladies.github.io/jinx/reference/verify_social_handles.md)
  : Verify that social media handles exist
- [`crop_directory_image()`](https://rladies.github.io/jinx/reference/crop_directory_image.md)
  : Crop and resize a directory profile image
- [`optimize_image()`](https://rladies.github.io/jinx/reference/optimize_image.md)
  : Optimize an image for web display

## Blogs

Blog content management

- [`blog_check_links()`](https://rladies.github.io/jinx/reference/blog_check_links.md)
  : Check blog URLs and RSS feeds for broken links
- [`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md)
  : Auto-generate a blog entry JSON from a URL
- [`blog_post_checklist()`](https://rladies.github.io/jinx/reference/blog_post_checklist.md)
  : Post blog PR checklist
- [`validate_blog_entry()`](https://rladies.github.io/jinx/reference/validate_blog_entry.md)
  : Validate blog entry JSON files against schema

## Chapters

Chapter lifecycle management

- [`create_chapter()`](https://rladies.github.io/jinx/reference/create_chapter.md)
  : Create a new chapter JSON file
- [`chapter_create_setup()`](https://rladies.github.io/jinx/reference/chapter_create_setup.md)
  : Create a new chapter setup issue
- [`chapter_create_update()`](https://rladies.github.io/jinx/reference/chapter_create_update.md)
  : Create a chapter update issue
- [`create_chapter_json_pr()`](https://rladies.github.io/jinx/reference/create_chapter_json_pr.md)
  : Create a chapter JSON PR on the website repo
- [`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md)
  : Check chapter health across the organization

## Reports

Activity and health reporting

- [`report_format_markdown()`](https://rladies.github.io/jinx/reference/report_format_markdown.md)
  : Format a report as markdown
- [`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md)
  : Generate an organization activity report
- [`report_publish()`](https://rladies.github.io/jinx/reference/report_publish.md)
  : Publish a report as a GitHub issue
- [`chapter_report_health()`](https://rladies.github.io/jinx/reference/chapter_report_health.md)
  : Generate a chapter health report

## PR review

Automated pull request review

- [`review_pr()`](https://rladies.github.io/jinx/reference/review_pr.md)
  : Run all PR review automation
- [`check_pr_naming()`](https://rladies.github.io/jinx/reference/check_pr_naming.md)
  : Check file naming conventions in a PR

## Airtable sync

Airtable bidirectional sync

- [`sync_directory_airtable()`](https://rladies.github.io/jinx/reference/sync_directory_airtable.md)
  : Sync directory entries from Airtable
- [`sync_global_team_airtable()`](https://rladies.github.io/jinx/reference/sync_global_team_airtable.md)
  [`sync_gt_airtable()`](https://rladies.github.io/jinx/reference/sync_global_team_airtable.md)
  : Sync global team data from Airtable

## Website automation

Website PR management and contributor greetings

- [`website_merge_pending()`](https://rladies.github.io/jinx/reference/website_merge_pending.md)
  : Auto-merge PRs with pending label when date matches
- [`greet_contributor()`](https://rladies.github.io/jinx/reference/greet_contributor.md)
  : Post a greeting on new PRs/issues from non-team members

## Chapter monitoring

Chapter activity monitoring and outreach

- [`monitor_chapter_status()`](https://rladies.github.io/jinx/reference/monitor_chapter_status.md)
  : Monitor chapter activity status
- [`prepare_inactivity_emails()`](https://rladies.github.io/jinx/reference/prepare_inactivity_emails.md)
  : Send inactivity warning emails

## Slack

Slack messaging and automation

- [`slack_invite_send()`](https://rladies.github.io/jinx/reference/slack_invite_send.md)
  : Request a Slack invitation for someone not yet on the workspace
- [`slack_invites_send()`](https://rladies.github.io/jinx/reference/slack_invites_send.md)
  : Send pending Slack invitations
- [`slack_post_message()`](https://rladies.github.io/jinx/reference/slack_post_message.md)
  : Post a message to a Slack channel
- [`slack_welcome_member()`](https://rladies.github.io/jinx/reference/slack_welcome_member.md)
  : Welcome a new member to an RLadies+ Slack workspace
- [`subscribe_slack_rss()`](https://rladies.github.io/jinx/reference/subscribe_slack_rss.md)
  : Subscribe an RSS feed to a Slack channel
- [`common_welcome_channels()`](https://rladies.github.io/jinx/reference/common_welcome_channels.md)
  : Channels common to both RLadies+ Slack workspaces
- [`default_welcome_channels()`](https://rladies.github.io/jinx/reference/default_welcome_channels.md)
  : Default starter channels for the RLadies+ Slack welcome

## GHA dashboard

GitHub Actions workflow status

- [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md)
  : Generate GitHub Actions dashboard data
- [`gha_publish_dashboard()`](https://rladies.github.io/jinx/reference/gha_publish_dashboard.md)
  : Publish GHA dashboard as a GitHub issue

## Contributors

Contributor tracking and recognition

- [`list_contributors()`](https://rladies.github.io/jinx/reference/list_contributors.md)
  : List contributors for a repository
- [`list_org_contributors()`](https://rladies.github.io/jinx/reference/list_org_contributors.md)
  : Collect contributors across multiple repos
- [`format_contributors()`](https://rladies.github.io/jinx/reference/format_contributors.md)
  : Generate a contributors markdown section
- [`contributor_thank()`](https://rladies.github.io/jinx/reference/contributor_thank.md)
  : Thank a contributor when their PR is merged
- [`contributor_welcome()`](https://rladies.github.io/jinx/reference/contributor_welcome.md)
  : Welcome a first-time contributor
- [`contributors_update()`](https://rladies.github.io/jinx/reference/contributors_update.md)
  : Generate and update a contributors list for a repo

## Events

Chapter event management

- [`events_create_summary()`](https://rladies.github.io/jinx/reference/events_create_summary.md)
  : Create a formatted event summary
- [`events_list_chapter()`](https://rladies.github.io/jinx/reference/events_list_chapter.md)
  : List events for a chapter
- [`events_publish_summary()`](https://rladies.github.io/jinx/reference/events_publish_summary.md)
  : Publish event summary as a GitHub issue
- [`events_sync_chapters()`](https://rladies.github.io/jinx/reference/events_sync_chapters.md)
  : Sync events across all chapters

## Analytics

Org-wide activity analytics

- [`collect_chapter_activity()`](https://rladies.github.io/jinx/reference/collect_chapter_activity.md)
  : Collect chapter activity data
- [`collect_contributor_growth()`](https://rladies.github.io/jinx/reference/collect_contributor_growth.md)
  : Collect contributor growth data
- [`compute_activity_trends()`](https://rladies.github.io/jinx/reference/compute_activity_trends.md)
  : Compute activity trends
- [`format_analytics_markdown()`](https://rladies.github.io/jinx/reference/format_analytics_markdown.md)
  : Format analytics as markdown
- [`analytics_generate_dashboard()`](https://rladies.github.io/jinx/reference/analytics_generate_dashboard.md)
  : Generate analytics dashboard
- [`analytics_publish_dashboard()`](https://rladies.github.io/jinx/reference/analytics_publish_dashboard.md)
  : Publish analytics dashboard as a GitHub issue

## Website analytics

Plausible website performance reports

- [`collect_website_analytics()`](https://rladies.github.io/jinx/reference/collect_website_analytics.md)
  : Collect website analytics from Plausible
- [`format_website_analytics()`](https://rladies.github.io/jinx/reference/format_website_analytics.md)
  : Format website analytics as markdown
- [`generate_website_report()`](https://rladies.github.io/jinx/reference/generate_website_report.md)
  : Generate a website analytics report
- [`publish_website_report()`](https://rladies.github.io/jinx/reference/publish_website_report.md)
  : Publish website analytics as a GitHub issue

## Conference coordination

CFP tracking and speaker recommendations

- [`cfp_check_deadlines()`](https://rladies.github.io/jinx/reference/cfp_check_deadlines.md)
  : Check CFP deadlines and post reminders
- [`cfp_create_issue()`](https://rladies.github.io/jinx/reference/cfp_create_issue.md)
  : Create a CFP tracking issue
- [`cfp_list_open()`](https://rladies.github.io/jinx/reference/cfp_list_open.md)
  : List open CFPs tracked as GitHub issues
- [`cfp_recommend_speaker()`](https://rladies.github.io/jinx/reference/cfp_recommend_speaker.md)
  : Recommend a speaker for a conference
- [`list_speaker_recommendations()`](https://rladies.github.io/jinx/reference/list_speaker_recommendations.md)
  : List speaker recommendations for a conference
- [`generate_conference_report()`](https://rladies.github.io/jinx/reference/generate_conference_report.md)
  : Generate conference coordination report

## Internationalization

Template translations

- [`translate_template()`](https://rladies.github.io/jinx/reference/translate_template.md)
  : Translate a template with language fallback
- [`list_supported_languages()`](https://rladies.github.io/jinx/reference/list_supported_languages.md)
  : List supported languages
- [`get_chapter_language()`](https://rladies.github.io/jinx/reference/get_chapter_language.md)
  : Get a chapter's preferred language
- [`i18n_coverage_check()`](https://rladies.github.io/jinx/reference/i18n_coverage_check.md)
  : Check translation coverage across languages
- [`i18n_translations_validate()`](https://rladies.github.io/jinx/reference/i18n_translations_validate.md)
  : Validate translations for placeholder consistency

## Configuration

Config loading utilities

- [`load_labels_config()`](https://rladies.github.io/jinx/reference/load_labels_config.md)
  : Load file-path to label mappings
- [`load_review_rules()`](https://rladies.github.io/jinx/reference/load_review_rules.md)
  : Load PR review rules
- [`load_teams_config()`](https://rladies.github.io/jinx/reference/load_teams_config.md)
  : Load teams configuration

## Templates

Response and template utilities

- [`post_reply()`](https://rladies.github.io/jinx/reference/post_reply.md)
  : Post a reply comment on an issue or PR
