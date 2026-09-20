import { slack_user_email } from "./slack-api.js";

// Workspace check for the worker's one remaining local slash command
// (`shorten`). Global-team authorization for privileged commands now lives
// entirely in R (`cmd_authorize()`), since every command that needed it
// (feedback, questions) is now dispatched, not handled locally.
export function slack_is_organizer_workspace(env, teamId) {
  return Boolean(env.SLACK_ORGANIZER_TEAM_ID) && teamId === env.SLACK_ORGANIZER_TEAM_ID;
}

// Leadership authorization for the invite-link command. Unlike the global-team
// check above, this trusts a single principal by **verified email** (resolved
// via users.info) rather than a Slack user id in the directory, and it is
// deliberately NOT scoped to the organiser workspace: leadership rotates the
// community invite link from the community workspace they administer, so the
// email match is the sole gate. That is safe only because Slack verifies email
// ownership -- a colliding community identity can't satisfy it. Do not add a
// workspace check without confirming where leadership runs the command, or
// you'll lock them out. Default account is leadership@rladies.org; override via
// INVITE_ADMIN_EMAIL. Fails closed like slack_global_team_authorize: a lookup
// error is denied with a distinct "try again" message.
const AUTHZ_NOT_LEADERSHIP =
  "🔒 Updating the invite link is limited to the RLadies+ Leadership account (leadership@rladies.org).";
const AUTHZ_LEADERSHIP_UNVERIFIABLE =
  "😿 I couldn't verify your account just now (I may be missing permission to read your email). Please try again in a moment.";

export async function slack_leadership_authorize(env, { teamId, userId }) {
  const admin = (env.INVITE_ADMIN_EMAIL || "leadership@rladies.org")
    .trim()
    .toLowerCase();
  let email;
  try {
    email = await slack_user_email(env, teamId, userId);
  } catch (e) {
    console.warn("leadership authz check failed:", e.message);
    return { ok: false, message: AUTHZ_LEADERSHIP_UNVERIFIABLE };
  }
  // A null email means we couldn't read it (often a missing users:read.email
  // scope), not a confirmed non-match -- report that as unverifiable rather
  // than telling the real leadership account it isn't leadership.
  if (!email) {
    return { ok: false, message: AUTHZ_LEADERSHIP_UNVERIFIABLE };
  }
  return email.toLowerCase() === admin
    ? { ok: true, message: null }
    : { ok: false, message: AUTHZ_NOT_LEADERSHIP };
}
