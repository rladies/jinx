import { rag_question_answer } from "./rag.js";
import { question_capture } from "./question-log.js";
import { fetch_failure_quip } from "./quips.js";
import { github_dispatch_send } from "./github-dispatch.js";
import {
  slack_assistant_set_status,
  slack_assistant_set_suggested_prompts,
  slack_assistant_set_title,
  slack_conversations_replies,
  slack_file_upload_text,
  slack_message_post,
  slack_reaction_add,
  slack_reaction_remove,
  slack_team_is_allowed,
} from "./slack-api.js";

const LONG_ANSWER_THRESHOLD = 3000;

const ASSISTANT_CONFIG_URL =
  "https://raw.githubusercontent.com/rladies/jinx/main/inst/config/assistant-prompts.json";

const ASSISTANT_CONFIG_FALLBACK = {
  title: "RLadies+ Q&A with Jinx",
  prompts_title: "Try asking…",
  prompts: [
    {
      title: "What is RLadies+?",
      message: "What is RLadies+ and what does it stand for?",
    },
    {
      title: "Start a chapter",
      message: "How do I start an RLadies+ chapter?",
    },
    {
      title: "Code of conduct",
      message: "Where can I find the RLadies+ code of conduct?",
    },
    {
      title: "Upcoming events",
      message: "What RLadies+ events are coming up?",
    },
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
    ctx.waitUntil(
      github_dispatch_send(env, "slack-event", {
        kind: "team_join",
        team_id: teamId,
        event: { user: event.user },
      }).catch((e) => console.error("team_join dispatch failed:", e)),
    );
    return new Response("", { status: 200 });
  }

  if (event.type === "assistant_thread_started") {
    if (!slack_team_is_allowed(env, teamId))
      return new Response("", { status: 200 });
    ctx.waitUntil(
      slack_event_handle_assistant_start(env, teamId, event.assistant_thread),
    );
    return new Response("", { status: 200 });
  }

  if (event.type === "reaction_added") {
    if (!slack_team_is_allowed(env, teamId))
      return new Response("", { status: 200 });
    ctx.waitUntil(
      slack_event_handle_reaction(env, teamId, event, payload.event_id),
    );
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
        event.user,
      ),
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
          "🐈‍⬛ I only roam in the RLadies+ organisers and community " +
          "workspaces — sorry, house rules! If you think you should have " +
          "access, ping the RLadies+ global team in https://github.com/rladies/jinx.",
      }).catch((e) => console.error("Refusal post failed:", e)),
    );
    return new Response("", { status: 200 });
  }

  ctx.waitUntil(
    slack_event_handle_mention(env, teamId, {
      channel,
      messageTs,
      threadTs,
      query,
      userId,
    }),
  );

  return new Response("", { status: 200 });
}

async function slack_event_handle_mention(env, teamId, msg) {
  const { channel, messageTs, threadTs } = msg;
  await slack_reaction_add(env, teamId, {
    channel,
    timestamp: messageTs,
    name: "eyes",
  }).catch((e) => console.error("reaction add (eyes) failed:", e));

  try {
    await slack_event_answer_post(env, teamId, msg);
    await slack_reaction_remove(env, teamId, {
      channel,
      timestamp: messageTs,
      name: "eyes",
    }).catch((e) => console.error("reaction remove (eyes) failed:", e));
    await slack_reaction_add(env, teamId, {
      channel,
      timestamp: messageTs,
      name: "white_check_mark",
    }).catch((e) => console.error("reaction add (check) failed:", e));
  } catch (err) {
    console.error("RAG answer failed:", err);
    await slack_reaction_remove(env, teamId, {
      channel,
      timestamp: messageTs,
      name: "eyes",
    }).catch(() => {});
    await slack_reaction_add(env, teamId, {
      channel,
      timestamp: messageTs,
      name: "x",
    }).catch(() => {});
    await slack_message_post(env, teamId, {
      channel,
      thread_ts: threadTs,
      text: fetch_failure_quip(),
    }).catch((e) => console.error("Fallback post failed:", e));
  }
}

async function slack_event_answer_post(env, teamId, msg) {
  const { channel, threadTs, messageTs, query, userId } = msg;
  if (!query) {
    await slack_message_post(env, teamId, {
      channel,
      thread_ts: threadTs,
      text: `Hi <@${userId}>! 🔮 Ask me a question about RLadies+ — I'll go padding through the guide and the website to find an answer. (Type slowly, I have no thumbs.)`,
    });
    return;
  }

  const history = await slack_thread_history(
    env,
    teamId,
    channel,
    threadTs,
    messageTs,
  );
  const { answer, outcome, top_score, sources } = await rag_question_answer(
    env,
    query,
    history,
  );
  const answerTs = await slack_event_post_answer(env, teamId, {
    channel,
    threadTs,
    answer,
  });
  await question_capture(env, {
    teamId,
    channel,
    answerTs,
    question: query,
    outcome,
    top_score,
    sources,
  });
}

async function slack_thread_history(env, teamId, channel, threadTs, currentTs) {
  if (!threadTs) return [];
  const [botUserId, res] = await Promise.all([
    slack_bot_user_id(env, teamId),
    slack_conversations_replies(env, teamId, {
      channel,
      ts: threadTs,
      limit: 20,
    }).catch((e) => {
      console.warn("thread history fetch failed:", e.message);
      return null;
    }),
  ]);
  if (!res) return [];
  if (!botUserId) {
    console.warn("thread history dropped: bot_user_id missing from team KV");
    return [];
  }
  const out = [];
  for (const m of res.messages || []) {
    if (!m || !m.text || m.subtype) continue;
    if (currentTs && m.ts === currentTs) continue;
    const content = slack_event_strip_mention(m.text || "");
    if (!content) continue;
    out.push({
      role: m.user === botUserId ? "assistant" : "user",
      content,
    });
  }
  return out;
}

async function slack_bot_user_id(env, teamId) {
  if (!env.SLACK_TOKENS) return null;
  const team = await env.SLACK_TOKENS.get(`team:${teamId}`, "json").catch(
    () => null,
  );
  return team?.bot_user_id || null;
}

// Cheap pre-filters only — team allowlist (by the caller), message-type,
// bot-message-match, and dedup — before spinning up a GitHub Actions
// container. Most reactions in a workspace are not on the bot's own
// messages, so filtering here keeps dispatch volume sane; the actual
// tallying/vote-apply logic lives in R (see question_log.R's
// reaction_event_apply()).
async function slack_event_handle_reaction(env, teamId, event, eventId) {
  if (event.item?.type !== "message") return;
  if (!env.SLACK_TOKENS) return;

  const botUserId = await slack_bot_user_id(env, teamId);
  if (!botUserId || event.item_user !== botUserId) return;

  if (eventId) {
    const dedupeKey = `reaction_seen:${eventId}`;
    const seen = await env.SLACK_TOKENS.get(dedupeKey).catch(() => null);
    if (seen) return;
    await env.SLACK_TOKENS.put(dedupeKey, "1", {
      expirationTtl: 24 * 60 * 60,
    }).catch((e) => console.warn("reaction_seen write failed:", e));
  }

  const reaction = (event.reaction || "").split("::")[0];
  if (!reaction) return;

  await github_dispatch_send(env, "slack-event", {
    kind: "reaction_added",
    team_id: teamId,
    event: { reaction, item: event.item },
  }).catch((e) => console.error("reaction dispatch failed:", e));
}

async function slack_event_handle_dm(
  env,
  teamId,
  channel,
  messageTs,
  threadTs,
  text,
  userId,
) {
  if (!userId) return;

  const isAssistantThread = Boolean(threadTs);
  const postBase = { channel };
  if (threadTs) postBase.thread_ts = threadTs;

  if (isAssistantThread) {
    await slack_assistant_set_status(env, teamId, {
      channelId: channel,
      threadTs,
      status: "is padding through the RLadies+ guide…",
    }).catch((e) => console.warn("assistant setStatus failed:", e.message));
  } else {
    await slack_reaction_add(env, teamId, {
      channel,
      timestamp: messageTs,
      name: "eyes",
    }).catch((e) => console.error("DM reaction add failed:", e));
  }

  try {
    const query = (text || "").trim();
    if (!query) {
      await slack_message_post(env, teamId, {
        ...postBase,
        text: "Hi! 🔮 Ask me a question about RLadies+ — I'll go padding through the guide and the website to find an answer.",
      });
    } else {
      const history = await slack_thread_history(
        env,
        teamId,
        channel,
        threadTs,
        messageTs,
      );
      const { answer, outcome, top_score, sources } =
        await rag_question_answer(env, query, history);
      const answerTs = await slack_event_post_answer(env, teamId, {
        channel,
        threadTs: threadTs || undefined,
        answer,
      });
      await question_capture(env, {
        teamId,
        channel,
        answerTs,
        question: query,
        outcome,
        top_score,
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
      await slack_reaction_remove(env, teamId, {
        channel,
        timestamp: messageTs,
        name: "eyes",
      }).catch(() => {});
      await slack_reaction_add(env, teamId, {
        channel,
        timestamp: messageTs,
        name: "white_check_mark",
      }).catch(() => {});
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
      await slack_reaction_remove(env, teamId, {
        channel,
        timestamp: messageTs,
        name: "eyes",
      }).catch(() => {});
      await slack_reaction_add(env, teamId, {
        channel,
        timestamp: messageTs,
        name: "x",
      }).catch(() => {});
    }
    await slack_message_post(env, teamId, {
      ...postBase,
      text: fetch_failure_quip(),
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
  }).catch((e) =>
    console.warn("assistant setSuggestedPrompts failed:", e.message),
  );
}

export function slack_event_strip_mention(text) {
  if (!text) return "";
  return text
    .replace(/<@[A-Z0-9]+(\|[^>]+)?>/g, "")
    .replace(/<!subteam\^[A-Z0-9]+(\|[^>]+)?>/g, "")
    .replace(/<!(channel|here|everyone)>/g, "")
    .trim();
}

function slack_event_format_answer_markdown(answer) {
  return ["# Jinx — RLadies+ answer", "", answer].join("\n") + "\n";
}

async function slack_event_post_answer(
  env,
  teamId,
  { channel, threadTs, answer },
) {
  if (answer.length <= LONG_ANSWER_THRESHOLD) {
    const body = { channel, text: answer };
    if (threadTs) body.thread_ts = threadTs;
    const res = await slack_message_post(env, teamId, body);
    return res?.ts || null;
  }

  const filename = `jinx-answer-${Date.now()}.md`;
  const content = slack_event_format_answer_markdown(answer);
  try {
    await slack_file_upload_text(env, teamId, {
      channel,
      threadTs,
      filename,
      title: "Jinx answer",
      content,
      initialComment:
        "🔮 That answer ran long — I've batted it into a file so it's easier to read.",
    });
    return null;
  } catch (e) {
    console.warn("file upload fallback:", e.message);
    const body = { channel, text: answer };
    if (threadTs) body.thread_ts = threadTs;
    const res = await slack_message_post(env, teamId, body);
    return res?.ts || null;
  }
}
