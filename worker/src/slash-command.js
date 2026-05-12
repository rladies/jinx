import { github_dispatch_send } from "./github-dispatch.js";
import { slack_team_is_allowed } from "./slack-api.js";

export async function slack_command_handle(env, ctx, body) {
  const params = new URLSearchParams(body);

  if (params.get("type") === "url_verification") {
    return Response.json({ challenge: params.get("challenge") });
  }

  const teamId = params.get("team_id") || "";
  if (!slack_team_is_allowed(env, teamId)) {
    console.warn(`Rejected slash command from team ${teamId}`);
    return Response.json({
      response_type: "ephemeral",
      text: workspaceNotSupportedMessage(),
    });
  }

  const command = (params.get("text") || "").trim();
  const responseUrl = params.get("response_url") || "";

  if (!command || command === "help") {
    return Response.json({
      response_type: "ephemeral",
      text: await fetchHelpText(),
    });
  }

  const ack = Response.json({
    response_type: "ephemeral",
    text: randomAck(command),
  });

  const dispatchPromise = github_dispatch_send(env, {
    command,
    user_id: params.get("user_id") || "",
    user_name: params.get("user_name") || "",
    channel_id: params.get("channel_id") || "",
    channel_name: params.get("channel_name") || "",
    response_url: responseUrl,
  }).catch(async (err) => {
    console.error("Dispatch failed:", err);
    if (responseUrl) {
      await fetch(responseUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          response_type: "ephemeral",
          text: `😿 Oops! Jinx couldn't start that command. The GitHub dispatch failed — please try again in a moment or let a maintainer know.\n\n_Error: ${err.message}_`,
        }),
      });
    }
  });

  ctx.waitUntil(dispatchPromise);
  return ack;
}

const ACKS = [
  "🔮 On it! Casting `/jinx {cmd}`...",
  "✨ One moment — conjuring `/jinx {cmd}` for you...",
  "🐈‍⬛ Jinx stretches, yawns, and gets to work on `/jinx {cmd}`...",
  "💜 Say no more! Running `/jinx {cmd}`...",
  "🧹 Sweeping into action with `/jinx {cmd}`...",
  "📮 Message received! Working on `/jinx {cmd}`...",
  "🪄 Abracadabra... running `/jinx {cmd}`!",
  "🐾 Padding over to handle `/jinx {cmd}`...",
  "⚡ Zap! On it — `/jinx {cmd}` coming right up...",
  "🌙 Jinx heard you! Running `/jinx {cmd}`...",
  "🎀 Consider it done (well, almost) — running `/jinx {cmd}`...",
  "☕ Jinx grabs a coffee and gets to work on `/jinx {cmd}`...",
  "🔧 Tinkering away on `/jinx {cmd}`...",
  "💫 Your wish is my command! Running `/jinx {cmd}`...",
  "🐈‍⬛ *purrs approvingly* — on it with `/jinx {cmd}`...",
];

const WAIT_NOTE =
  "\n_This may take a couple of minutes — Jinx will reply here when done._";

function randomAck(command) {
  const template = ACKS[Math.floor(Math.random() * ACKS.length)];
  return template.replace(/\{cmd\}/g, command) + WAIT_NOTE;
}

const HELP_URL =
  "https://raw.githubusercontent.com/rladies/jinx/main/inst/commands/help.md";

async function fetchHelpText() {
  try {
    const res = await fetch(HELP_URL, {
      headers: { "User-Agent": "rladies-jinx" },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const md = await res.text();
    return "🔮 " + md.replace(/\|/g, "│").replace(/---/g, "———");
  } catch (e) {
    console.error("Failed to fetch help text:", e);
    return "🔮 *Jinx* — I couldn't load the help text right now. Try `/jinx help` again in a moment, or check https://github.com/rladies/jinx";
  }
}

function workspaceNotSupportedMessage() {
  return (
    "🐈‍⬛ Jinx only runs in the RLadies+ organisers and community workspaces. " +
    "If you think you should have access, ping the RLadies+ global team in " +
    "https://github.com/rladies/jinx."
  );
}
