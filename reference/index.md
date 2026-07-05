# Package index

## Commands

Issue comment command interface

- [`cmd_authorize()`](https://rladies.github.io/jinx/reference/cmd_authorize.md)
  : Authorize a parsed command before execution
- [`cmd_execute()`](https://rladies.github.io/jinx/reference/cmd_execute.md)
  : Execute a parsed jinx command
- [`cmd_parse()`](https://rladies.github.io/jinx/reference/cmd_parse.md)
  : Parse a jinx command from an issue comment

## Team management

Global team onboarding and offboarding

- [`gt_check_invitations()`](https://rladies.github.io/jinx/reference/gt_check_invitations.md)
  : Check pending global team invitations
- [`gt_create_offboarding()`](https://rladies.github.io/jinx/reference/gt_create_offboarding.md)
  : Create a global team offboarding issue
- [`gt_finalize_offboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_offboarding.md)
  : Finalize global team offboarding by removing user from teams
- [`gt_finalize_onboarding()`](https://rladies.github.io/jinx/reference/gt_finalize_onboarding.md)
  : Finalize global team onboarding for an accepted member
- [`gt_invite()`](https://rladies.github.io/jinx/reference/gt_invite.md)
  : Invite a user to the RLadies+ global team
- [`gt_remind_stale()`](https://rladies.github.io/jinx/reference/gt_remind_stale.md)
  : Send reminders on stale global team onboarding/offboarding issues
- [`gt_schedule_onboarding_meeting()`](https://rladies.github.io/jinx/reference/gt_schedule_onboarding_meeting.md)
  : Open the onboarding meeting poll and post it to the onboarding issue

## Announcements

Cross-platform blog post announcements

- [`announce_create_message()`](https://rladies.github.io/jinx/reference/announce_create_message.md)
  : Create a formatted announcement message
- [`announce_post()`](https://rladies.github.io/jinx/reference/announce_post.md)
  : Announce a blog post across multiple platforms
- [`announce_post_bluesky()`](https://rladies.github.io/jinx/reference/announce_post_bluesky.md)
  : Post an announcement to Bluesky
- [`announce_post_mastodon()`](https://rladies.github.io/jinx/reference/announce_post_mastodon.md)
  : Post an announcement to Mastodon
- [`announce_post_reply()`](https://rladies.github.io/jinx/reference/announce_post_reply.md)
  : Post a reply comment on an issue or PR
- [`announce_send_newsletter()`](https://rladies.github.io/jinx/reference/announce_send_newsletter.md)
  : Send a newsletter via ConvertKit
- [`li_get_version()`](https://rladies.github.io/jinx/reference/li_get_version.md)
  : Get LinkedIn API version string
- [`li_media_upload()`](https://rladies.github.io/jinx/reference/li_media_upload.md)
  : Upload media to LinkedIn
- [`li_oauth()`](https://rladies.github.io/jinx/reference/li_oauth.md) :
  Perform LinkedIn OAuth authentication
- [`li_post_write()`](https://rladies.github.io/jinx/reference/li_post_write.md)
  : Post to LinkedIn
- [`li_req()`](https://rladies.github.io/jinx/reference/li_req.md) :
  Create a base LinkedIn API request
- [`li_urn_me()`](https://rladies.github.io/jinx/reference/li_urn_me.md)
  : Get the LinkedIn URN for the authenticated user
- [`short_url()`](https://rladies.github.io/jinx/reference/short_url.md)
  : Shorten a URL using the Short.io API
- [`tags2hash()`](https://rladies.github.io/jinx/reference/tags2hash.md)
  : Convert tags to hashtag string
- [`random_emoji()`](https://rladies.github.io/jinx/reference/random_emoji.md)
  : Select a random emoji

## Directory

Directory entry management and validation

- [`directory_crop_image()`](https://rladies.github.io/jinx/reference/directory_crop_image.md)
  : Crop and resize a directory profile image
- [`directory_optimize_image()`](https://rladies.github.io/jinx/reference/directory_optimize_image.md)
  : Optimize an image for web display
- [`directory_sync_airtable()`](https://rladies.github.io/jinx/reference/directory_sync_airtable.md)
  : Sync directory entries from Airtable
- [`directory_validate_filename()`](https://rladies.github.io/jinx/reference/directory_validate_filename.md)
  : Validate a directory entry filename
- [`directory_verify_handles()`](https://rladies.github.io/jinx/reference/directory_verify_handles.md)
  : Verify that social media handles exist
- [`validate_directory_pr()`](https://rladies.github.io/jinx/reference/validate_directory_pr.md)
  : Post an automated directory review as a PR checklist comment
- [`validate_directory_entries()`](https://rladies.github.io/jinx/reference/validate_directory_entries.md)
  : Validate directory entry JSON files against schema

## Blogs

Blog content management

- [`blog_add_pr()`](https://rladies.github.io/jinx/reference/blog_add_pr.md)
  : Add a community blog entry via a pull request
- [`blog_check_links()`](https://rladies.github.io/jinx/reference/blog_check_links.md)
  : Check blog URLs and RSS feeds for broken links
- [`blog_check_links_repo()`](https://rladies.github.io/jinx/reference/blog_check_links_repo.md)
  : Check community blog links from the awesome-rladies-creations repo
- [`blog_create_entry()`](https://rladies.github.io/jinx/reference/blog_create_entry.md)
  : Auto-generate a blog entry JSON file from a URL
- [`validate_blog_entry()`](https://rladies.github.io/jinx/reference/validate_blog_entry.md)
  : Validate blog entry JSON files against schema

## Chapters

Chapter lifecycle management

- [`chapter_create()`](https://rladies.github.io/jinx/reference/chapter_create.md)
  : Create a new chapter JSON file
- [`chapter_create_setup()`](https://rladies.github.io/jinx/reference/chapter_create_setup.md)
  : Create a new chapter setup issue
- [`chapter_create_update()`](https://rladies.github.io/jinx/reference/chapter_create_update.md)
  : Create a chapter update issue
- [`chapter_create_pr()`](https://rladies.github.io/jinx/reference/chapter_create_pr.md)
  : Create a chapter JSON PR on the website repo
- [`chapter_check_health()`](https://rladies.github.io/jinx/reference/chapter_check_health.md)
  : Check chapter health across the organization

## Reports

Activity and health reporting

- [`report_format_markdown()`](https://rladies.github.io/jinx/reference/report_format_markdown.md)
  : Format a report as markdown
- [`report_generate()`](https://rladies.github.io/jinx/reference/report_generate.md)
  : Generate an organization activity report
- [`chapter_report_health()`](https://rladies.github.io/jinx/reference/chapter_report_health.md)
  : Generate a chapter health report

## PR review

Automated pull request review

- [`review_check_pr_naming()`](https://rladies.github.io/jinx/reference/review_check_pr_naming.md)
  : Check file naming conventions in a PR
- [`review_run()`](https://rladies.github.io/jinx/reference/review_run.md)
  : Run all PR review automation

## Airtable sync

Airtable bidirectional sync

- [`directory_sync_airtable()`](https://rladies.github.io/jinx/reference/directory_sync_airtable.md)
  : Sync directory entries from Airtable

## Website automation

Website PR management

- [`website_merge_pending()`](https://rladies.github.io/jinx/reference/website_merge_pending.md)
  : Auto-merge PRs with pending label when date matches

## Chapter monitoring

Chapter activity monitoring and outreach

- [`chapter_monitor_status()`](https://rladies.github.io/jinx/reference/chapter_monitor_status.md)
  : Monitor chapter activity status
- [`prepare_inactivity_emails()`](https://rladies.github.io/jinx/reference/prepare_inactivity_emails.md)
  : Send inactivity warning emails

## Slack

Slack messaging and automation

- [`slack_invite_batch()`](https://rladies.github.io/jinx/reference/slack_invite_batch.md)
  : Send pending Slack invitations
- [`slack_invite_request()`](https://rladies.github.io/jinx/reference/slack_invite_request.md)
  : Request a Slack invitation for someone not yet on the workspace
- [`slack_post_message()`](https://rladies.github.io/jinx/reference/slack_post_message.md)
  : Post a message to a Slack channel
- [`slack_subscribe_rss()`](https://rladies.github.io/jinx/reference/slack_subscribe_rss.md)
  : Post a request to subscribe an RSS feed to a Slack channel

## GHA dashboard

GitHub Actions workflow status

- [`gha_generate_dashboard()`](https://rladies.github.io/jinx/reference/gha_generate_dashboard.md)
  : Generate GitHub Actions dashboard data

## Contributors

Contributor tracking and recognition

- [`contributor_format()`](https://rladies.github.io/jinx/reference/contributor_format.md)
  : Generate a contributors markdown section
- [`contributor_list()`](https://rladies.github.io/jinx/reference/contributor_list.md)
  : List contributors for a repository
- [`contributor_list_org()`](https://rladies.github.io/jinx/reference/contributor_list_org.md)
  : Collect contributors across multiple repos
- [`contributor_update()`](https://rladies.github.io/jinx/reference/contributor_update.md)
  : Generate and update a contributors list for a repo

## GitHub helpers

Reusable PR/issue automation across repos

- [`gh_branch_upsert()`](https://rladies.github.io/jinx/reference/gh_branch_upsert.md)
  : Create or reset a branch to match a base ref
- [`gh_greet_contributor()`](https://rladies.github.io/jinx/reference/gh_greet_contributor.md)
  : Greet a new PR author
- [`gh_open_or_update_pr()`](https://rladies.github.io/jinx/reference/gh_open_or_update_pr.md)
  : Open a PR, or return the existing open PR for a branch
- [`gh_post_checklist()`](https://rladies.github.io/jinx/reference/gh_post_checklist.md)
  : Post a content review checklist on a PR
- [`gh_thank_contributor()`](https://rladies.github.io/jinx/reference/gh_thank_contributor.md)
  : Thank a contributor when their PR is merged
- [`gh_welcome_contributor()`](https://rladies.github.io/jinx/reference/gh_welcome_contributor.md)
  : Welcome a contributor on a new PR or issue

## Events

Chapter event management

- [`event_create_summary()`](https://rladies.github.io/jinx/reference/event_create_summary.md)
  : Create a formatted event summary
- [`event_list_chapter()`](https://rladies.github.io/jinx/reference/event_list_chapter.md)
  : List events for a chapter
- [`event_sync_chapters()`](https://rladies.github.io/jinx/reference/event_sync_chapters.md)
  : Sync events across all chapters

## Meeting scheduling

Group meeting-time polls via the samkoma API

- [`meeting_poll_best()`](https://rladies.github.io/jinx/reference/meeting_poll_best.md)
  : Get the ranked best slots for a poll
- [`meeting_poll_create()`](https://rladies.github.io/jinx/reference/meeting_poll_create.md)
  : Create a meeting-scheduling poll on samkoma
- [`meeting_poll_format_best()`](https://rladies.github.io/jinx/reference/meeting_poll_format_best.md)
  : Format ranked best slots as markdown
- [`meeting_poll_format_created()`](https://rladies.github.io/jinx/reference/meeting_poll_format_created.md)
  : Format a created poll as a markdown announcement
- [`meeting_poll_get()`](https://rladies.github.io/jinx/reference/meeting_poll_get.md)
  : Fetch a poll and its aggregated responses
- [`meeting_poll_ics()`](https://rladies.github.io/jinx/reference/meeting_poll_ics.md)
  : Export the locked slot of a poll as an iCalendar (.ics) string
- [`meeting_poll_lock()`](https://rladies.github.io/jinx/reference/meeting_poll_lock.md)
  : Lock in (or clear) the chosen slot for a poll

## Analytics

Org-wide activity analytics

- [`analytics_collect_chapter_activity()`](https://rladies.github.io/jinx/reference/analytics_collect_chapter_activity.md)
  : Collect chapter activity data
- [`analytics_collect_contributor_growth()`](https://rladies.github.io/jinx/reference/analytics_collect_contributor_growth.md)
  : Collect contributor growth data
- [`analytics_compute_trends()`](https://rladies.github.io/jinx/reference/analytics_compute_trends.md)
  : Compute activity trends
- [`analytics_format_markdown()`](https://rladies.github.io/jinx/reference/analytics_format_markdown.md)
  : Format analytics as markdown
- [`analytics_generate_dashboard()`](https://rladies.github.io/jinx/reference/analytics_generate_dashboard.md)
  : Generate analytics dashboard

## Website analytics

Plausible website performance reports

- [`website_collect_analytics()`](https://rladies.github.io/jinx/reference/website_collect_analytics.md)
  : Collect website analytics from Plausible
- [`website_format_analytics()`](https://rladies.github.io/jinx/reference/website_format_analytics.md)
  : Format website analytics as markdown
- [`website_generate_report()`](https://rladies.github.io/jinx/reference/website_generate_report.md)
  : Generate a website analytics report
- [`website_publish_report()`](https://rladies.github.io/jinx/reference/website_publish_report.md)
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
- [`conference_generate_report()`](https://rladies.github.io/jinx/reference/conference_generate_report.md)
  : Generate conference coordination report
- [`conference_list_speakers()`](https://rladies.github.io/jinx/reference/conference_list_speakers.md)
  : List speaker recommendations for a conference

## Internationalization

Template translations

- [`i18n_check_coverage()`](https://rladies.github.io/jinx/reference/i18n_check_coverage.md)
  : Check translation coverage across languages
- [`i18n_get_chapter_language()`](https://rladies.github.io/jinx/reference/i18n_get_chapter_language.md)
  : Get a chapter's preferred language
- [`i18n_list_languages()`](https://rladies.github.io/jinx/reference/i18n_list_languages.md)
  : List supported languages
- [`i18n_translate_template()`](https://rladies.github.io/jinx/reference/i18n_translate_template.md)
  : Translate a template with language fallback
- [`i18n_validate_translations()`](https://rladies.github.io/jinx/reference/i18n_validate_translations.md)
  : Validate translations for placeholder consistency

## Configuration

Config loading utilities

- [`load_copilot_review_config()`](https://rladies.github.io/jinx/reference/load_copilot_review_config.md)
  : Load the Copilot review bridge configuration
- [`load_labels_config()`](https://rladies.github.io/jinx/reference/load_labels_config.md)
  : Load file-path to label mappings
- [`load_rag_sources()`](https://rladies.github.io/jinx/reference/load_rag_sources.md)
  : Load the configured RAG source list
- [`load_review_rules()`](https://rladies.github.io/jinx/reference/load_review_rules.md)
  : Load PR review rules
- [`load_teams_config()`](https://rladies.github.io/jinx/reference/load_teams_config.md)
  : Load teams configuration

## Copilot review

Summon GitHub Copilot to run grimoire review gates

- [`copilot_request_review()`](https://rladies.github.io/jinx/reference/copilot_request_review.md)
  : Request GitHub Copilot as a reviewer on a pull request
- [`copilot_review_pr()`](https://rladies.github.io/jinx/reference/copilot_review_pr.md)
  : Summon a GitHub Copilot review on a pull request
- [`copilot_sync_repo()`](https://rladies.github.io/jinx/reference/copilot_sync_repo.md)
  : Sync grimoire review skills into a repo as Copilot instructions

## RAG indexer

Build the Cloudflare Vectorize index that powers the Slack bot

- [`rag_index_build()`](https://rladies.github.io/jinx/reference/rag_index_build.md)
  : Build the Jinx RAG index
- [`gather_rag_source()`](https://rladies.github.io/jinx/reference/gather_rag_source.md)
  : Dispatch a source spec to the appropriate gather function
- [`chunk_markdown()`](https://rladies.github.io/jinx/reference/chunk_markdown.md)
  : Chunk markdown into retrieval-sized pieces
- [`rag_chunk_id()`](https://rladies.github.io/jinx/reference/rag_chunk_id.md)
  : Stable vector ID for a chunk
- [`cloudflare_embed()`](https://rladies.github.io/jinx/reference/cloudflare_embed.md)
  : Embed texts with a Cloudflare Workers AI model
- [`cloudflare_vectorize_upsert()`](https://rladies.github.io/jinx/reference/cloudflare_vectorize_upsert.md)
  : Upsert vectors into a Cloudflare Vectorize index
- [`cloudflare_account_id()`](https://rladies.github.io/jinx/reference/cloudflare_account_id.md)
  : Discover the Cloudflare account ID for a token
