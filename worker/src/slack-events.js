import { answerQuestion } from "./rag.js";
import { postSlackMessage, isAllowedTeam } from "./slack-api.js";

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

  const teamId = payload.team_id;
  const channel = event.channel;
  const threadTs = event.thread_ts || event.ts;
  const query = stripMention(event.text);
  const userId = event.user;

  if (!isAllowedTeam(env, teamId)) {
    console.warn(`Rejected app_mention from team ${teamId}`);
    ctx.waitUntil(
      postSlackMessage(env, teamId, {
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
    answerAndPost(env, teamId, channel, threadTs, query, userId).catch(
      async (err) => {
        console.error("RAG answer failed:", err);
        await postSlackMessage(env, teamId, {
          channel,
          thread_ts: threadTs,
          text: "🐈‍⬛ Sorry — Jinx couldn't fetch an answer right now. Try again in a moment?",
        }).catch((e) => console.error("Fallback post failed:", e));
      }
    )
  );

  return new Response("", { status: 200 });
}

async function answerAndPost(env, teamId, channel, threadTs, query, userId) {
  if (!query) {
    await postSlackMessage(env, teamId, {
      channel,
      thread_ts: threadTs,
      text: `Hi <@${userId}>! Ask me a question about RLadies+ — I'll look it up in the guide and the website. 🔮`,
    });
    return;
  }

  const { answer, sources } = await answerQuestion(env, query);
  const text = formatAnswer(answer, sources);

  await postSlackMessage(env, teamId, { channel, thread_ts: threadTs, text });
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
