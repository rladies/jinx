#!/usr/bin/env node
const required = [
  "WORKER_URL",
  "SLACK_HEALTHCHECK_BOT_TOKEN",
  "SLACK_HEALTHCHECK_CHANNEL",
  "SLACK_HEALTHCHECK_TEAM_ID",
  "SLACK_SIGNING_SECRET",
];

const missing = required.filter((k) => !process.env[k]);
if (missing.length) {
  console.error(`Missing required env vars: ${missing.join(", ")}`);
  process.exit(2);
}

const {
  WORKER_URL,
  SLACK_HEALTHCHECK_BOT_TOKEN: BOT,
  SLACK_HEALTHCHECK_CHANNEL: CHANNEL,
  SLACK_HEALTHCHECK_TEAM_ID: TEAM_ID,
  SLACK_SIGNING_SECRET: SIGNING_SECRET,
} = process.env;

const workerOrigin = WORKER_URL.replace(/\/+$/, "");
const results = [];
let hadFailure = false;

async function step(name, fn) {
  process.stdout.write(`• ${name}... `);
  try {
    await fn();
    process.stdout.write("ok\n");
    results.push({ name, ok: true });
  } catch (err) {
    hadFailure = true;
    process.stdout.write("FAIL\n");
    console.error(`  ${err.message}`);
    results.push({ name, ok: false, error: err.message });
  }
}

async function slackApi(method, body, token = BOT) {
  const res = await fetch(`https://slack.com/api/${method}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body || {}),
  });
  const data = await res.json();
  if (!data.ok) {
    throw new Error(`Slack ${method} failed: ${data.error}`);
  }
  return data;
}

async function signSlack(secret, timestamp, body) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    enc.encode(`v0:${timestamp}:${body}`)
  );
  const hex = [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `v0=${hex}`;
}

let messageTs;
let botUserId;

await step("Slack auth.test (token is alive)", async () => {
  const data = await slackApi("auth.test");
  if (data.team_id !== TEAM_ID) {
    throw new Error(
      `Bot belongs to team ${data.team_id}, expected ${TEAM_ID}`
    );
  }
  botUserId = data.user_id;
});

await step("chat.postMessage (chat:write scope)", async () => {
  const stamp = new Date().toISOString();
  const data = await slackApi("chat.postMessage", {
    channel: CHANNEL,
    text: `🩺 Jinx smoke test — ${stamp}`,
  });
  messageTs = data.ts;
  if (!messageTs) throw new Error("no ts returned");
});

await step("reactions.add (reactions:write scope)", async () => {
  await slackApi("reactions.add", {
    channel: CHANNEL,
    timestamp: messageTs,
    name: "white_check_mark",
  });
});

await step("reactions.remove (reactions:read + reactions:write)", async () => {
  await slackApi("reactions.remove", {
    channel: CHANNEL,
    timestamp: messageTs,
    name: "white_check_mark",
  });
});

await step("bookmarks.list (bookmarks:read scope)", async () => {
  await slackApi("bookmarks.list", { channel_id: CHANNEL });
});

await step("conversations.info (channels:read scope)", async () => {
  await slackApi("conversations.info", { channel: CHANNEL });
});

await step("chat.delete (cleanup health-check message)", async () => {
  await slackApi("chat.delete", { channel: CHANNEL, ts: messageTs });
});

await step("Worker GET / responds with 200", async () => {
  const res = await fetch(`${workerOrigin}/`);
  if (res.status !== 200) throw new Error(`HTTP ${res.status}`);
});

await step("Worker GET /slack/install issues 302 to slack.com", async () => {
  const res = await fetch(`${workerOrigin}/slack/install`, { redirect: "manual" });
  if (res.status !== 302) throw new Error(`HTTP ${res.status}`);
  const location = res.headers.get("location") || "";
  if (!location.startsWith("https://slack.com/oauth/v2/authorize")) {
    throw new Error(`unexpected Location: ${location}`);
  }
});

await step("Worker /slack/command rejects bad signatures with 401", async () => {
  const res = await fetch(`${workerOrigin}/slack/command`, {
    method: "POST",
    headers: {
      "x-slack-request-timestamp": String(Math.floor(Date.now() / 1000)),
      "x-slack-signature": "v0=deadbeef",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "team_id=" + encodeURIComponent(TEAM_ID) + "&text=help",
  });
  if (res.status !== 401) throw new Error(`expected 401, got ${res.status}`);
});

await step("Worker /slack/command help round-trip with signed body", async () => {
  const body = new URLSearchParams({
    team_id: TEAM_ID,
    text: "help",
    user_id: "U_SMOKE",
    user_name: "smoke-test",
    channel_id: CHANNEL,
    channel_name: "jinx-healthcheck",
    response_url: "https://example.invalid/no-op",
  }).toString();
  const ts = String(Math.floor(Date.now() / 1000));
  const sig = await signSlack(SIGNING_SECRET, ts, body);
  const res = await fetch(`${workerOrigin}/slack/command`, {
    method: "POST",
    headers: {
      "x-slack-request-timestamp": ts,
      "x-slack-signature": sig,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (res.status !== 200) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  if (data.response_type !== "ephemeral") {
    throw new Error(`response_type: ${data.response_type}`);
  }
  if (!data.text || !data.text.toLowerCase().includes("jinx")) {
    throw new Error(`unexpected help text: ${(data.text || "").slice(0, 80)}`);
  }
});

const passed = results.filter((r) => r.ok).length;
console.log(`\n${passed}/${results.length} checks passed`);
process.exit(hadFailure ? 1 : 0);
