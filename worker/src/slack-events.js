import { answerQuestion } from "./rag.js";
import { postSlackMessage } from "./slack-api.js";

export async function handleSlackEvent(env, ctx, body) {
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
  if (event.type !== "app_mention") {
    return new Response("", { status: 200 });
  }

  const channel = event.channel;
  const threadTs = event.thread_ts || event.ts;
  const query = stripMention(event.text);
  const userId = event.user;

  ctx.waitUntil(
    answerAndPost(env, channel, threadTs, query, userId).catch(async (err) => {
      console.error("RAG answer failed:", err);
      await postSlackMessage(env, {
        channel,
        thread_ts: threadTs,
        text: "🐈‍⬛ Sorry — Jinx couldn't fetch an answer right now. Try again in a moment?",
      }).catch((e) => console.error("Fallback post failed:", e));
    })
  );

  return new Response("", { status: 200 });
}

async function answerAndPost(env, channel, threadTs, query, userId) {
  if (!query) {
    await postSlackMessage(env, {
      channel,
      thread_ts: threadTs,
      text: `Hi <@${userId}>! Ask me a question about R-Ladies — I'll look it up in the guide and the website. 🔮`,
    });
    return;
  }

  const { answer, sources } = await answerQuestion(env, query);
  const text = formatAnswer(answer, sources);

  await postSlackMessage(env, { channel, thread_ts: threadTs, text });
}

function stripMention(text) {
  if (!text) return "";
  return text.replace(/<@[A-Z0-9]+>/g, "").trim();
}

function formatAnswer(answer, sources) {
  if (!sources || sources.length === 0) return answer;
  const list = sources
    .map((s, i) => `${i + 1}. <${s.url}|${s.title}>`)
    .join("\n");
  return `${answer}\n\n*Sources:*\n${list}`;
}
