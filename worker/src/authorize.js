// Global-team authorization for the worker's local slash commands.
//
// Mirrors the R gate in R/authorize.R (cmd_authorize / gt_actor_is_authorized)
// so local commands share ONE source of truth with the dispatched commands: the
// Airtable "Member" directory. Same rules as the R side:
//   * Slack identity is only trusted in the organiser workspace — community
//     usernames are mutable and the workspace is openly joinable, so a colliding
//     handle there must never authorize a privileged action.
//   * The check fails closed: an unknown actor is denied, and a directory that
//     cannot be read is also denied (with a distinct "try again" message).
//
// The directory schema matches inst/config/teams.yml `member_directory` (the R
// defaults). If that config changes, update both.
const MEMBER_DIRECTORY = {
  base_id: "appZjaV7eM0Y9FsHZ",
  table: "Member",
  slack_field: "organiser_slack",
};

const AUTHZ_DENIED =
  "🚫 Peeking at what folks ask me is limited to the RLadies+ global team. " +
  "If you're a global team member, check that your Slack username is recorded " +
  "in the global team directory.";
const AUTHZ_WORKSPACE =
  "🚫 This one's for the RLadies+ global team, and I only trust that from the " +
  "organisers workspace — sorry, house rules!";
const AUTHZ_UNVERIFIABLE =
  "😿 I couldn't check your global-team membership just now. Please try again " +
  "in a moment.";

function normalize_handle(x) {
  return String(x ?? "")
    .trim()
    .replace(/^@/, "")
    .toLowerCase();
}

async function member_slack_handles(env) {
  const handles = new Set();
  let offset;
  do {
    const url = new URL(
      `https://api.airtable.com/v0/${MEMBER_DIRECTORY.base_id}/${encodeURIComponent(MEMBER_DIRECTORY.table)}`,
    );
    if (offset) url.searchParams.set("offset", offset);
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${env.AIRTABLE_API_KEY}` },
    });
    if (!res.ok) throw new Error(`Airtable list failed: HTTP ${res.status}`);
    const data = await res.json();
    for (const record of data.records || []) {
      const handle = normalize_handle(record.fields?.[MEMBER_DIRECTORY.slack_field]);
      if (handle) handles.add(handle);
    }
    offset = data.offset;
  } while (offset);
  return handles;
}

// Returns { ok, message }. ok === true means the actor may run the command;
// otherwise `message` is an ephemeral refusal. Never throws — a lookup failure
// resolves to a fail-closed { ok: false } with the unverifiable message.
export async function slack_global_team_authorize(env, { teamId, userName }) {
  if (!env.SLACK_ORGANIZER_TEAM_ID || teamId !== env.SLACK_ORGANIZER_TEAM_ID) {
    return { ok: false, message: AUTHZ_WORKSPACE };
  }
  if (!env.AIRTABLE_API_KEY) {
    return { ok: false, message: AUTHZ_UNVERIFIABLE };
  }
  const actor = normalize_handle(userName);
  if (!actor) {
    return { ok: false, message: AUTHZ_DENIED };
  }
  try {
    const handles = await member_slack_handles(env);
    return handles.has(actor)
      ? { ok: true, message: null }
      : { ok: false, message: AUTHZ_DENIED };
  } catch (e) {
    console.warn("global-team authz check failed:", e.message);
    return { ok: false, message: AUTHZ_UNVERIFIABLE };
  }
}
