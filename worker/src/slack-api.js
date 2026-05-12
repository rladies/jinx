export async function postSlackMessage(env, { channel, thread_ts, text, blocks }) {
  const body = { channel, text };
  if (thread_ts) body.thread_ts = thread_ts;
  if (blocks) body.blocks = blocks;

  const res = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_ORGANISER_TOKEN}`,
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

export async function getSlackToken(env, teamId) {
  if (teamId && env.SLACK_TOKENS) {
    const data = await env.SLACK_TOKENS.get(`team:${teamId}`, "json");
    if (data?.bot_token) return data.bot_token;
  }

  if (env.SLACK_COMMUNITY_TOKEN) {
    console.warn(
      "Using legacy SLACK_COMMUNITY_TOKEN — complete OAuth install to remove this fallback"
    );
    return env.SLACK_COMMUNITY_TOKEN;
  }

  throw new Error(`No Slack token found for team ${teamId}`);
}

export async function verifySlackSignature(signingSecret, timestamp, body, expected) {
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
