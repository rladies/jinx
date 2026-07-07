// Global-team authorization for the worker's local slash commands.
//
// Shares ONE source of truth with the dispatched commands: the Airtable member
// directory ("Global team overview"). Rules:
//   * Slack identity is only trusted in the organiser workspace — community
//     usernames are mutable and the workspace is openly joinable, so a colliding
//     identity there must never authorize a privileged action.
//   * The check fails closed: an unknown actor is denied, and a directory that
//     cannot be read is also denied (with a distinct "try again" message).
//
// Matching is on the Slack **user id** (the slash command's `user_id`) against
// the directory's `slack_user_id` column. User ids are stable, unique, and
// always present in the payload — unlike the display-name/@mention text in
// `organiser_slack`, which is informal and (under Enterprise Grid) not even
// resolvable via users.info. The table is referenced by its stable table id.
const MEMBER_DIRECTORY = {
  base_id: "appZjaV7eM0Y9FsHZ",
  table: "tblfFWklqjtGdBLiT",
  id_field: "organiser_slack_id",
};

const AUTHZ_DENIED =
  "🚫 Peeking at what folks ask me is limited to the RLadies+ global team. " +
  "If you're a global team member, ask a maintainer to add your Slack member " +
  "ID to the `organiser_slack_id` column of the global team directory.";
const AUTHZ_WORKSPACE =
  "🚫 This one's for the RLadies+ global team, and I only trust that from the " +
  "organisers workspace — sorry, house rules!";
const AUTHZ_UNVERIFIABLE =
  "😿 I couldn't check your global-team membership just now. Please try again " +
  "in a moment.";

function normalize_id(x) {
  return String(x ?? "")
    .trim()
    .toUpperCase();
}

async function member_slack_ids(env) {
  const ids = new Set();
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
      const id = normalize_id(record.fields?.[MEMBER_DIRECTORY.id_field]);
      if (id) ids.add(id);
    }
    offset = data.offset;
  } while (offset);
  return ids;
}

// Returns { ok, message }. ok === true means the actor may run the command;
// otherwise `message` is an ephemeral refusal. Never throws — a lookup failure
// resolves to a fail-closed { ok: false } with the unverifiable message.
export async function slack_global_team_authorize(env, { teamId, userId }) {
  if (!env.SLACK_ORGANIZER_TEAM_ID || teamId !== env.SLACK_ORGANIZER_TEAM_ID) {
    return { ok: false, message: AUTHZ_WORKSPACE };
  }
  if (!env.AIRTABLE_API_KEY) {
    return { ok: false, message: AUTHZ_UNVERIFIABLE };
  }
  const actor = normalize_id(userId);
  if (!actor) {
    return { ok: false, message: AUTHZ_DENIED };
  }
  try {
    const ids = await member_slack_ids(env);
    return ids.has(actor)
      ? { ok: true, message: null }
      : { ok: false, message: AUTHZ_DENIED };
  } catch (e) {
    console.warn("global-team authz check failed:", e.message);
    return { ok: false, message: AUTHZ_UNVERIFIABLE };
  }
}
