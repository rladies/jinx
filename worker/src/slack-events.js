import { rag_question_answer } from "./rag.js";
import { pending_link_key } from "./airtable-invite.js";
import {
  slack_assistant_set_status,
  slack_assistant_set_suggested_prompts,
  slack_assistant_set_title,
  slack_channel_id_lookup,
  slack_conversations_open,
  slack_file_upload_text,
  slack_message_post,
  slack_reaction_add,
  slack_reaction_remove,
  slack_team_is_allowed,
  slack_user_info_fetch,
  slack_users_profile_get,
} from "./slack-api.js";

const LONG_ANSWER_THRESHOLD = 3000;

const WELCOME_CONFIG_URL =
  "https://raw.githubusercontent.com/rladies/jinx/main/inst/config/welcome-channels.json";

const WELCOME_TEMPLATE_URL = (workspace) =>
  `https://raw.githubusercontent.com/rladies/jinx/main/inst/templates/slack-welcome-${workspace}.md`;

async function welcome_config_fetch() {
  try {
    const res = await fetch(WELCOME_CONFIG_URL, {
      headers: { "User-Agent": "rladies-jinx" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    console.warn("Welcome config fetch failed:", e.message);
    return null;
  }
}

async function welcome_template_fetch(workspace) {
  try {
    const res = await fetch(WELCOME_TEMPLATE_URL(workspace), {
      headers: { "User-Agent": "rladies-jinx" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.text();
  } catch (e) {
    console.warn(`Welcome template fetch failed (${workspace}):`, e.message);
    return null;
  }
}

function workspace_for_team(env, teamId) {
  if (env.SLACK_ORGANIZER_TEAM_ID && teamId === env.SLACK_ORGANIZER_TEAM_ID) {
    return "organisers";
  }
  return "community";
}

async function channel_mention(env, teamId, name) {
  const id = await slack_channel_id_lookup(env, teamId, name);
  return id ? `<#${id}|${name}>` : `#${name}`;
}

const ASSISTANT_CONFIG_URL =
  "https://raw.githubusercontent.com/rladies/jinx/main/inst/config/assistant-prompts.json";

const ASSISTANT_CONFIG_FALLBACK = {
  title: "RLadies+ Q&A with Jinx",
  prompts_title: "Try asking…",
  prompts: [
    { title: "What is RLadies+?", message: "What is RLadies+ and what does it stand for?" },
    { title: "Start a chapter", message: "How do I start an RLadies+ chapter?" },
    { title: "Code of conduct", message: "Where can I find the RLadies+ code of conduct?" },
    { title: "Upcoming events", message: "What RLadies+ events are coming up?" },
  ],
};

async function assistant_config_fetch() {
  try {
    const res = await fetch(ASSISTANT_CONFIG_URL, {
      headers: { "User-Agent": "rladies-jinx" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    console.warn("Assistant config fetch failed; using fallback:", e.message);
    return ASSISTANT_CONFIG_FALLBACK;
  }
}

export async function slack_event_handle(env, ctx, body) {
  let payload;
  try {
    payload = JSON.parse(body);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  if (payload.type === "url_verification") {
    return Response.json({ challenge: payload.challenge });
  }

  if (payload.type !== "event_callback") {
    return new Response("", { status: 200 });
  }

  const event = payload.event || {};
  const teamId = payload.team_id;

  if (event.type === "team_join") {
    if (!slack_team_is_allowed(env, teamId)) {
      console.warn(`Ignoring team_join from team ${teamId}`);
      return new Response("", { status: 200 });
    }
    ctx.waitUntil(slack_event_handle_team_join(env, teamId, event.user));
    return new Response("", { status: 200 });
  }

  if (event.type === "assistant_thread_started") {
    if (!slack_team_is_allowed(env, teamId)) return new Response("", { status: 200 });
    ctx.waitUntil(slack_event_handle_assistant_start(env, teamId, event.assistant_thread));
    return new Response("", { status: 200 });
  }

  if (event.type === "reaction_added") {
    if (!slack_team_is_allowed(env, teamId)) return new Response("", { status: 200 });
    ctx.waitUntil(slack_event_handle_reaction(env, teamId, event));
    return new Response("", { status: 200 });
  }

  if (event.type === "message" && event.channel_type === "im") {
    if (event.bot_id || event.subtype) {
      return new Response("", { status: 200 });
    }
    if (!slack_team_is_allowed(env, teamId)) {
      console.warn(`Ignoring DM from team ${teamId}`);
      return new Response("", { status: 200 });
    }
    ctx.waitUntil(
      slack_event_handle_dm(
        env,
        teamId,
        event.channel,
        event.ts,
        event.thread_ts || null,
        event.text,
        event.user
      )
    );
    return new Response("", { status: 200 });
  }

  if (event.type !== "app_mention") {
    return new Response("", { status: 200 });
  }

  const channel = event.channel;
  const messageTs = event.ts;
  const threadTs = event.thread_ts || event.ts;
  const query = slack_event_strip_mention(event.text);
  const userId = event.user;

  if (typeof channel === "string" && channel.startsWith("D")) {
    return new Response("", { status: 200 });
  }

  if (!slack_team_is_allowed(env, teamId)) {
    console.warn(`Rejected app_mention from team ${teamId}`);
    ctx.waitUntil(
      slack_message_post(env, teamId, {
        channel,
        thread_ts: threadTs,
        text:
          "🐈‍⬛ Jinx only runs in the RLadies+ organisers and community " +
          "workspaces. If you think you should have access, ping the " +
          "RLadies+ global team in https://github.com/rladies/jinx.",
      }).catch((e) => console.error("Refusal post failed:", e))
    );
    return new Response("", { status: 200 });
  }

  ctx.waitUntil(
    slack_event_handle_mention(env, teamId, channel, messageTs, threadTs, query, userId)
  );

  return new Response("", { status: 200 });
}

async function slack_event_handle_mention(env, teamId, channel, messageTs, threadTs, query, userId) {
  await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
    .catch((e) => console.error("reaction add (eyes) failed:", e));

  try {
    await slack_event_answer_post(env, teamId, channel, threadTs, query, userId);
    await slack_reaction_remove(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
      .catch((e) => console.error("reaction remove (eyes) failed:", e));
    await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "white_check_mark" })
      .catch((e) => console.error("reaction add (check) failed:", e));
  } catch (err) {
    console.error("RAG answer failed:", err);
    await slack_reaction_remove(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
      .catch(() => {});
    await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "x" })
      .catch(() => {});
    await slack_message_post(env, teamId, {
      channel,
      thread_ts: threadTs,
      text: "🐈‍⬛ Sorry — Jinx couldn't fetch an answer right now. Try again in a moment?",
    }).catch((e) => console.error("Fallback post failed:", e));
  }
}

async function slack_event_answer_post(env, teamId, channel, threadTs, query, userId) {
  if (!query) {
    await slack_message_post(env, teamId, {
      channel,
      thread_ts: threadTs,
      text: `Hi <@${userId}>! Ask me a question about RLadies+ — I'll look it up in the guide and the website. 🔮`,
    });
    return;
  }

  const { answer, sources } = await rag_question_answer(env, query);
  await slack_event_post_answer(env, teamId, { channel, threadTs, answer, sources });
}

async function slack_event_handle_reaction(env, teamId, event) {
  if (event.item?.type !== "message") return;
  if (!env.SLACK_TOKENS) return;

  const team = await env.SLACK_TOKENS.get(`team:${teamId}`, "json").catch(() => null);
  const botUserId = team?.bot_user_id;
  if (!botUserId || event.item_user !== botUserId) return;

  const day = new Date().toISOString().slice(0, 10);
  const reaction = (event.reaction || "").split("::")[0];
  if (!reaction) return;
  const key = `reaction_log:${teamId}:${day}:${reaction}`;
  const prior = await env.SLACK_TOKENS.get(key, "json").catch(() => null);
  const count = (prior?.count || 0) + 1;
  await env.SLACK_TOKENS.put(
    key,
    JSON.stringify({ count, last_at: new Date().toISOString() }),
    { expirationTtl: 180 * 24 * 60 * 60 }
  ).catch((e) => console.error("reaction_log write failed:", e));
}

async function slack_event_handle_team_join(env, teamId, user) {
  if (!user?.id) return;
  const email = user.profile?.email || "";
  const link = await slack_pending_link_consume(env, email);

  await slack_user_mapping_persist(env, teamId, user.id, email, link);

  const channelId = await slack_dm_open(env, teamId, user.id);
  if (!channelId) return;

  const workspace = workspace_for_team(env, teamId);
  const text = await welcome_message_render(env, teamId, workspace, user.id, link);

  await slack_message_post(env, teamId, {
    channel: channelId,
    text,
    unfurl_links: false,
    unfurl_media: false,
  }).catch((e) => console.error("Welcome DM post failed:", e));
}

async function welcome_message_render(env, teamId, workspace, userId, link) {
  const [cfg, template] = await Promise.all([
    welcome_config_fetch(),
    welcome_template_fetch(workspace),
  ]);

  if (!cfg || !template) {
    return welcome_message_fallback(userId, link);
  }

  const ws = cfg[workspace] || {};
  const welcomeChannelName = ws.welcome_channel || "welcome";
  const helpChannelName = ws.help_channel || "help-how_to_slack";
  const cocUrl = cfg.coc_url || "https://rladies.org/about/coc/";
  const starterChannels = [...(cfg.common || []), ...(ws.extras || [])];

  const [welcomeMention, helpMention, ...starterMentions] = await Promise.all([
    channel_mention(env, teamId, welcomeChannelName),
    channel_mention(env, teamId, helpChannelName),
    ...starterChannels.map((c) => channel_mention(env, teamId, c.name)),
  ]);

  const starterLines = starterChannels
    .map((c, i) => `  - ${starterMentions[i]} — ${c.desc}`)
    .join("\n");

  let rendered = template
    .replace(/\{\{user_id\}\}/g, userId)
    .replace(/\{\{coc_url\}\}/g, cocUrl)
    .replace(/\{\{welcome_channel\}\}/g, welcomeMention)
    .replace(/\{\{help_channel\}\}/g, helpMention)
    .replace(/\{\{starter_channels\}\}/g, starterLines);

  if (link) {
    rendered += "\n\n_:sparkles: I matched you up with your RLadies+ chapter sign-up — welcome aboard!_";
  }
  return rendered;
}

function welcome_message_fallback(userId, link) {
  const chapterLine = link
    ? "\n\nI matched you up with your RLadies+ chapter sign-up — welcome aboard! 💜"
    : "";
  return (
    `Hi <@${userId}>! 🔮 I'm Jinx, the RLadies+ community bot.` +
    chapterLine +
    "\n\nAsk me anything about RLadies+ — chapters, events, the guide, code of conduct — and I'll look it up for you."
  );
}

async function slack_event_handle_dm(env, teamId, channel, messageTs, threadTs, text, userId) {
  if (!userId) return;

  let mapping = null;
  if (env.SLACK_TOKENS) {
    const mappingKey = slack_user_mapping_key(teamId, userId);
    mapping = await env.SLACK_TOKENS.get(mappingKey, "json").catch(() => null);
  }
  if (!mapping) {
    mapping = await slack_user_first_dm_link(env, teamId, userId);
  }

  const isAssistantThread = Boolean(threadTs);
  const postBase = { channel };
  if (threadTs) postBase.thread_ts = threadTs;

  if (isAssistantThread) {
    await slack_assistant_set_status(env, teamId, {
      channelId: channel,
      threadTs,
      status: "is searching the RLadies+ guide…",
    }).catch((e) => console.warn("assistant setStatus failed:", e.message));
  } else {
    await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
      .catch((e) => console.error("DM reaction add failed:", e));
  }

  try {
    const query = (text || "").trim();
    if (!query) {
      await slack_message_post(env, teamId, {
        ...postBase,
        text: "Hi! Ask me a question about RLadies+ — I'll look it up in the guide and the website. 🔮",
      });
    } else {
      const { answer, sources } = await rag_question_answer(env, query);
      await slack_event_post_answer(env, teamId, {
        channel,
        threadTs: threadTs || undefined,
        answer,
        sources,
      });
    }

    if (isAssistantThread) {
      await slack_assistant_set_status(env, teamId, {
        channelId: channel,
        threadTs,
        status: "",
      }).catch(() => {});
    } else {
      await slack_reaction_remove(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
        .catch(() => {});
      await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "white_check_mark" })
        .catch(() => {});
    }
  } catch (err) {
    console.error("DM handling failed:", err);
    if (isAssistantThread) {
      await slack_assistant_set_status(env, teamId, {
        channelId: channel,
        threadTs,
        status: "",
      }).catch(() => {});
    } else {
      await slack_reaction_remove(env, teamId, { channel, timestamp: messageTs, name: "eyes" })
        .catch(() => {});
      await slack_reaction_add(env, teamId, { channel, timestamp: messageTs, name: "x" })
        .catch(() => {});
    }
    await slack_message_post(env, teamId, {
      ...postBase,
      text: "🐈‍⬛ Sorry — Jinx couldn't fetch an answer right now. Try again in a moment?",
    }).catch(() => {});
  }
}

async function slack_event_handle_assistant_start(env, teamId, thread) {
  const channelId = thread?.channel_id;
  const threadTs = thread?.thread_ts;
  if (!channelId || !threadTs) return;

  const cfg = await assistant_config_fetch();

  await slack_assistant_set_title(env, teamId, {
    channelId,
    threadTs,
    title: cfg.title,
  }).catch((e) => console.warn("assistant setTitle failed:", e.message));

  await slack_assistant_set_suggested_prompts(env, teamId, {
    channelId,
    threadTs,
    title: cfg.prompts_title,
    prompts: cfg.prompts,
  }).catch((e) => console.warn("assistant setSuggestedPrompts failed:", e.message));
}

async function slack_user_first_dm_link(env, teamId, userId) {
  try {
    const info = await slack_user_info_fetch(env, teamId, userId);
    const email = info?.user?.profile?.email || "";
    if (!email) return null;
    const link = await slack_pending_link_consume(env, email);
    return slack_user_mapping_persist(env, teamId, userId, email, link);
  } catch (e) {
    console.error("First-DM identity lookup failed:", e);
    return null;
  }
}

async function slack_pending_link_consume(env, email) {
  if (!email || !env.SLACK_TOKENS) return null;
  const key = pending_link_key(email);
  const link = await env.SLACK_TOKENS.get(key, "json").catch(() => null);
  if (link) {
    await env.SLACK_TOKENS.delete(key).catch((e) =>
      console.error("pending_link delete failed:", e)
    );
  }
  return link;
}

async function slack_user_mapping_persist(env, teamId, userId, email, link) {
  if (!env.SLACK_TOKENS) return null;
  let profile = null;
  try {
    const res = await slack_users_profile_get(env, teamId, userId);
    profile = res?.profile || null;
  } catch (e) {
    console.warn("users.profile.get failed for", userId, e.message);
  }
  const mapping = {
    slack_user_id: userId,
    team_id: teamId,
    email: email || null,
    tz: profile?.tz || null,
    real_name: profile?.real_name || null,
    pronouns: profile?.pronouns || null,
    airtable: link
      ? {
          record_id: link.record_id,
          base_id: link.base_id,
          table_id: link.table_id,
        }
      : null,
    linked_at: new Date().toISOString(),
  };
  await env.SLACK_TOKENS.put(
    slack_user_mapping_key(teamId, userId),
    JSON.stringify(mapping)
  );
  return mapping;
}

async function slack_dm_open(env, teamId, userId) {
  try {
    const res = await slack_conversations_open(env, teamId, { users: userId });
    return res?.channel?.id || null;
  } catch (e) {
    console.error("conversations.open failed:", e);
    return null;
  }
}

function slack_user_mapping_key(teamId, userId) {
  return `slack_user:${teamId}:${userId}`;
}

function slack_event_strip_mention(text) {
  if (!text) return "";
  return text.replace(/<@[A-Z0-9]+>/g, "").trim();
}

function slack_event_format_answer(answer, sources) {
  if (!sources || sources.length === 0) return answer;
  const list = sources
    .map((s, i) => `${i + 1}. <${s.url}|${s.title}>`)
    .join("\n");
  return `${answer}\n\n*Sources:*\n${list}`;
}

function slack_event_format_answer_markdown(answer, sources) {
  const lines = ["# Jinx — RLadies+ answer", "", answer];
  if (sources && sources.length) {
    lines.push("", "## Sources");
    for (const s of sources) lines.push(`- [${s.title}](${s.url})`);
  }
  return lines.join("\n") + "\n";
}

async function slack_event_post_answer(env, teamId, { channel, threadTs, answer, sources }) {
  const text = slack_event_format_answer(answer, sources);
  if (text.length <= LONG_ANSWER_THRESHOLD) {
    const body = { channel, text };
    if (threadTs) body.thread_ts = threadTs;
    await slack_message_post(env, teamId, body);
    return;
  }

  const filename = `jinx-answer-${Date.now()}.md`;
  const content = slack_event_format_answer_markdown(answer, sources);
  try {
    await slack_file_upload_text(env, teamId, {
      channel,
      threadTs,
      filename,
      title: "Jinx answer",
      content,
      initialComment: "🔮 The full answer was long — uploading as a file for easier reading.",
    });
  } catch (e) {
    console.warn("file upload fallback:", e.message);
    const body = { channel, text };
    if (threadTs) body.thread_ts = threadTs;
    await slack_message_post(env, teamId, body);
  }
}
