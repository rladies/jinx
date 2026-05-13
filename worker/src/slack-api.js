export async function slack_api_call(token, method, body) {
  const res = await fetch(`https://slack.com/api/${method}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body || {}),
  });
  const result = await res.json();
  if (!result.ok) {
    throw new Error(`Slack ${method} failed: ${result.error}`);
  }
  return result;
}

export async function slack_message_post(env, teamId, { channel, thread_ts, text, blocks }) {
  const token = await slack_token_get(env, teamId);
  const body = { channel, text };
  if (thread_ts) body.thread_ts = thread_ts;
  if (blocks) body.blocks = blocks;
  return slack_api_call(token, "chat.postMessage", body);
}

export async function slack_team_info_fetch(token) {
  return slack_api_call(token, "team.info", {});
}

export async function slack_reaction_add(env, teamId, { channel, timestamp, name }) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "reactions.add", { channel, timestamp, name });
}

export async function slack_reaction_remove(env, teamId, { channel, timestamp, name }) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "reactions.remove", { channel, timestamp, name });
}

export async function slack_conversations_open(env, teamId, { users }) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "conversations.open", { users });
}

export async function slack_conversations_join(env, teamId, channelId) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "conversations.join", { channel: channelId });
}

export async function slack_conversations_info(env, teamId, channelId) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "conversations.info", { channel: channelId });
}

export async function slack_conversations_list(env, teamId, { types = "public_channel", limit = 1000 } = {}) {
  const token = await slack_token_get(env, teamId);
  const channels = [];
  let cursor;
  do {
    const body = { types, limit, exclude_archived: true };
    if (cursor) body.cursor = cursor;
    const res = await slack_api_call(token, "conversations.list", body);
    for (const c of res.channels || []) channels.push(c);
    cursor = res.response_metadata?.next_cursor || null;
  } while (cursor);
  return channels;
}

const CHANNEL_INDEX_TTL_SECONDS = 3600;

export async function slack_channel_id_lookup(env, teamId, name) {
  if (!name || !env.SLACK_TOKENS) return null;
  const cacheKey = `channel_index:${teamId}`;
  let index = await env.SLACK_TOKENS.get(cacheKey, "json").catch(() => null);

  if (!index?.names) {
    try {
      const channels = await slack_conversations_list(env, teamId);
      const names = {};
      for (const c of channels) if (c.name && c.id) names[c.name] = c.id;
      index = { names, fetched_at: new Date().toISOString() };
      await env.SLACK_TOKENS.put(cacheKey, JSON.stringify(index), {
        expirationTtl: CHANNEL_INDEX_TTL_SECONDS,
      }).catch((e) => console.warn("channel_index write failed:", e.message));
    } catch (e) {
      console.warn("conversations.list failed:", e.message);
      return null;
    }
  }
  return index?.names?.[name] || null;
}

export async function slack_bookmarks_list(env, teamId, channelId) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "bookmarks.list", { channel_id: channelId });
}

export async function slack_bookmarks_add(env, teamId, { channelId, title, link, emoji }) {
  const token = await slack_token_get(env, teamId);
  const body = { channel_id: channelId, title, type: "link", link };
  if (emoji) body.emoji = emoji;
  return slack_api_call(token, "bookmarks.add", body);
}

export async function slack_reminders_add(env, teamId, { text, time, user }) {
  const token = await slack_token_get(env, teamId);
  const body = { text, time };
  if (user) body.user = user;
  return slack_api_call(token, "reminders.add", body);
}

export async function slack_assistant_set_status(env, teamId, { channelId, threadTs, status }) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "assistant.threads.setStatus", {
    channel_id: channelId,
    thread_ts: threadTs,
    status,
  });
}

export async function slack_assistant_set_title(env, teamId, { channelId, threadTs, title }) {
  const token = await slack_token_get(env, teamId);
  return slack_api_call(token, "assistant.threads.setTitle", {
    channel_id: channelId,
    thread_ts: threadTs,
    title,
  });
}

export async function slack_file_upload_text(env, teamId, { channel, threadTs, filename, title, content, initialComment }) {
  const token = await slack_token_get(env, teamId);
  const bytes = new TextEncoder().encode(content);

  const upload = await fetch("https://slack.com/api/files.getUploadURLExternal", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ filename, length: String(bytes.byteLength) }),
  }).then((r) => r.json());
  if (!upload.ok) {
    throw new Error(`Slack files.getUploadURLExternal failed: ${upload.error}`);
  }

  const put = await fetch(upload.upload_url, {
    method: "POST",
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
    body: bytes,
  });
  if (!put.ok) {
    throw new Error(`File upload PUT failed: HTTP ${put.status}`);
  }

  const completeBody = {
    files: [{ id: upload.file_id, title: title || filename }],
    channel_id: channel,
  };
  if (threadTs) completeBody.thread_ts = threadTs;
  if (initialComment) completeBody.initial_comment = initialComment;
  return slack_api_call(token, "files.completeUploadExternal", completeBody);
}

export async function slack_assistant_set_suggested_prompts(
  env,
  teamId,
  { channelId, threadTs, prompts, title }
) {
  const token = await slack_token_get(env, teamId);
  const body = {
    channel_id: channelId,
    thread_ts: threadTs,
    prompts,
  };
  if (title) body.title = title;
  return slack_api_call(token, "assistant.threads.setSuggestedPrompts", body);
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
