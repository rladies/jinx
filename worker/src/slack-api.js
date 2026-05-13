export async function slack_message_post(env, teamId, { channel, thread_ts, text, blocks }) {
  const token = await slack_token_get(env, teamId);

  const body = { channel, text };
  if (thread_ts) body.thread_ts = thread_ts;
  if (blocks) body.blocks = blocks;

  const res = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body),
  });

  const result = await res.json();
  if (!result.ok) {
    throw new Error(`Slack postMessage failed: ${result.error}`);
  }
  return result;
}

export async function slack_token_get(env, teamId) {
  if (!teamId) {
    throw new Error("slack_token_get requires a team id");
  }
  if (!env.SLACK_TOKENS) {
    throw new Error("SLACK_TOKENS KV binding not configured");
  }
  const data = await env.SLACK_TOKENS.get(`team:${teamId}`, "json");
  if (!data?.bot_token) {
    throw new Error(
      `No bot token for team ${teamId}. Install via /slack/install.`
    );
  }
  return data.bot_token;
}

export function slack_team_is_allowed(env, teamId) {
  if (!teamId) return false;
  const allowed = [env.SLACK_ORGANIZER_TEAM_ID, env.SLACK_COMMUNITY_TEAM_ID]
    .filter(Boolean);
  if (allowed.length === 0) {
    throw new Error(
      "Neither SLACK_ORGANIZER_TEAM_ID nor SLACK_COMMUNITY_TEAM_ID set; refusing all installs"
    );
  }
  return allowed.includes(teamId);
}

export async function slack_signature_verify(signingSecret, timestamp, body, expected) {
  if (!timestamp || !expected || !signingSecret) return false;

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp)) > 300) return false;

  const sigBasestring = `v0:${timestamp}:${body}`;
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(signingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(sigBasestring));
  const hex = [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return `v0=${hex}` === expected;
}
