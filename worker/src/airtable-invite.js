import { slack_team_is_allowed } from "./slack-api.js";
import { github_dispatch_send } from "./github-dispatch.js";

export async function airtable_webhook_handle(request, env, ctx) {
  const secret = env.AIRTABLE_WEBHOOK_SECRET;
  if (!secret) {
    console.error("AIRTABLE_WEBHOOK_SECRET is not configured");
    return new Response("Webhook not configured", { status: 500 });
  }
  const provided = request.headers.get("x-airtable-secret");
  if (provided !== secret) {
    return new Response("Unauthorized", { status: 401 });
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const email = payload.email || "";
  const name = payload.name || "";
  const chapter = payload.chapter || "";
  const recordId = payload.record_id || "";
  const baseId = payload.base_id || "";
  const tableId = payload.table_id || "";

  if (!email) {
    return new Response("Missing email", { status: 400 });
  }
  if (!baseId || !tableId || !recordId) {
    return new Response("Missing base_id, table_id, or record_id", { status: 400 });
  }

  if (!/^rec[A-Za-z0-9]{14}$/.test(recordId)) {
    return new Response("Invalid record_id", { status: 400 });
  }
  if (!/^app[A-Za-z0-9]{14}$/.test(baseId)) {
    return new Response("Invalid base_id", { status: 400 });
  }
  if (!/^tbl[A-Za-z0-9]{14}$/.test(tableId)) {
    return new Response("Invalid table_id", { status: 400 });
  }

  // Base-allowlist check, card building, and posting all now happen in R
  // (airtable_webhook_process(), triggered by this dispatch) - this handler
  // only verifies the webhook is genuinely from Airtable and shaped right.
  ctx.waitUntil(
    github_dispatch_send(env, "slack-event", {
      kind: "airtable_webhook",
      event: {
        email,
        name,
        chapter,
        record_id: recordId,
        base_id: baseId,
        table_id: tableId,
      },
    }).catch((e) => console.error("airtable_webhook dispatch failed:", e)),
  );

  return new Response("OK", { status: 200 });
}

export async function slack_interaction_handle(env, ctx, body) {
  const params = new URLSearchParams(body);

  let interaction;
  try {
    interaction = JSON.parse(params.get("payload"));
  } catch {
    return new Response("Invalid payload", { status: 400 });
  }

  if (interaction.type !== "block_actions") {
    return new Response("OK", { status: 200 });
  }

  const teamId = interaction.team?.id;
  const responseUrl = interaction.response_url;
  if (!slack_team_is_allowed(env, teamId)) {
    console.warn(`Rejected interaction from team ${teamId}`);
    if (responseUrl) {
      ctx.waitUntil(
        fetch(responseUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            response_type: "ephemeral",
            text:
              "🐈‍⬛ I only roam in the RLadies+ organisers and community " +
              "workspaces — sorry, house rules!",
          }),
        }).catch((e) => console.error("Refusal post failed:", e))
      );
    }
    return new Response("", { status: 200 });
  }

  const action = interaction.actions?.[0];
  if (!action) return new Response("OK", { status: 200 });

  const actionData = JSON.parse(action.value);
  const adminUser = interaction.user?.username || "unknown";

  // Ack immediately with a placeholder - R replaces this via response_url
  // once it actually processes the approve/deny/mark-sent action, which
  // can take a couple of minutes end-to-end via the GitHub Actions dispatch.
  ctx.waitUntil(
    fetch(responseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        replace_original: true,
        text: "⏳ Processing…",
      }),
    }).catch((e) => console.error("Processing ack failed:", e)),
  );

  ctx.waitUntil(
    github_dispatch_send(env, "slack-event", {
      kind: "slack_interaction",
      team_id: teamId,
      response_url: responseUrl,
      event: {
        action_id: action.action_id,
        action_data: actionData,
        admin_user: adminUser,
      },
    }).catch((e) => console.error("slack_interaction dispatch failed:", e)),
  );

  return new Response("", { status: 200 });
}
