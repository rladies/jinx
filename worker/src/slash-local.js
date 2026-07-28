import { slack_is_organizer_workspace } from "./authorize.js";
import { short_link_create } from "./short-links.js";

const LOCAL_COMMANDS = new Set(["shorten"]);

export function slash_is_local(command) {
  const verb = command.split(/\s+/)[0];
  return LOCAL_COMMANDS.has(verb);
}

// Link creation is restricted to the organiser workspace (not the openly
// joinable community one) so an open shortener can't be abused as a
// phishing/open-redirect vector by an arbitrary community member.
const ORGANIZER_WORKSPACE_COMMANDS = new Set(["shorten"]);

export function command_requires_organizer_workspace(command) {
  return ORGANIZER_WORKSPACE_COMMANDS.has(command.split(/\s+/)[0]);
}

export async function slash_local_handle(env, teamId, command, params, responseUrl) {
  const [verb, ...rest] = command.split(/\s+/);
  const args = rest.join(" ").trim();
  const userId = params.get("user_id") || "";

  if (command_requires_organizer_workspace(command) && !slack_is_organizer_workspace(env, teamId)) {
    await slash_respond(
      responseUrl,
      "🚫 Shortening links is for the organisers workspace only — sorry, house rules!",
    );
    return;
  }

  try {
    switch (verb) {
      case "shorten":
        return await slash_shorten(env, userId, args, responseUrl);
    }
  } catch (err) {
    console.error(`Local command "${verb}" failed:`, err);
    await slash_respond(responseUrl, `😿 ${verb} didn't quite land — paws-up: ${err.message}`);
  }
}

async function slash_shorten(env, userId, args, responseUrl) {
  const [rawUrl, slug] = (args || "").trim().split(/\s+/);
  if (!rawUrl) {
    await slash_respond(
      responseUrl,
      "Usage: `/jinx shorten <url> [slug]` — for example: `/jinx shorten https://guide.rladies.org/events/ conf-2026`",
    );
    return;
  }

  try {
    const { shortUrl, created } = await short_link_create(env, {
      url: rawUrl,
      slug,
      createdBy: userId,
    });
    const verb = created ? "Minted" : "Already had";
    await slash_respond(responseUrl, `🔗 ${verb} a short link: ${shortUrl}`);
  } catch (err) {
    await slash_respond(responseUrl, `😿 Couldn't shorten that: ${err.message}`);
  }
}

async function slash_respond(responseUrl, text) {
  if (!responseUrl) return;
  await fetch(responseUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ response_type: "ephemeral", text }),
  }).catch((e) => console.error("response_url post failed:", e));
}
