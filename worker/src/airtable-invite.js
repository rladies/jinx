import { getSlackToken, isAllowedTeam } from "./slack-api.js";

export async function handleAirtableWebhook(request, env) {
  const secret = env.AIRTABLE_WEBHOOK_SECRET;
  if (secret) {
    const provided = request.headers.get("x-airtable-secret");
    if (provided !== secret) {
      return new Response("Unauthorized", { status: 401 });
    }
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

  if (!email) {
    return new Response("Missing email", { status: 400 });
  }

  const blocks = inviteRequestBlocks({ email, name, chapter, recordId });

  const token = await getSlackToken(env, env.SLACK_COMMUNITY_TEAM_ID);

  const res = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      channel: env.SLACK_INVITE_CHANNEL,
      text: `New Slack invite request from ${name || email}`,
      blocks,
    }),
  });

  const result = await res.json();
  if (!result.ok) {
    console.error("Failed to post invite request to Slack:", result.error);
    return new Response(`Slack error: ${result.error}`, { status: 502 });
  }

  return new Response("OK", { status: 200 });
}

export async function handleSlackInteraction(env, ctx, body) {
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
  if (!isAllowedTeam(env, teamId)) {
    console.warn(`Rejected interaction from team ${teamId}`);
    if (responseUrl) {
      ctx.waitUntil(
        fetch(responseUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            response_type: "ephemeral",
            text:
              "🐈‍⬛ Jinx only runs in the RLadies+ organisers and community " +
              "workspaces.",
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

  if (action.action_id === "invite_approve") {
    ctx.waitUntil(processApproval(env, actionData, adminUser, responseUrl));
  } else if (action.action_id === "invite_deny") {
    ctx.waitUntil(processDenial(env, actionData, adminUser, responseUrl));
  } else if (action.action_id === "invite_mark_sent") {
    ctx.waitUntil(processInviteSent(env, actionData, adminUser, responseUrl));
  }

  return new Response("", { status: 200 });
}

async function processApproval(env, data, approver, responseUrl) {
  await fetch(responseUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      replace_original: true,
      blocks: approvalChecklistBlocks(data.email, approver, data.record_id),
      text: `Approved by @${approver} - invite ${data.email} manually`,
    }),
  });
}

async function processInviteSent(env, data, sender, responseUrl) {
  try {
    if (data.record_id && env.AIRTABLE_API_KEY) {
      await updateAirtableRecord(env, data.record_id, { invited: true });
    }

    const approverLine = data.approver
      ? ` — approved by @${data.approver}`
      : "";

    await fetch(responseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        replace_original: true,
        text: `✅ Invite sent to ${data.email} by @${sender}${approverLine}`,
      }),
    });
  } catch (err) {
    console.error("Mark-sent processing failed:", err);
    await fetch(responseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        replace_original: false,
        text: `😿 Failed to mark ${data.email} as invited in Airtable: ${err.message}`,
      }),
    });
  }
}

async function processDenial(env, data, adminUser, responseUrl) {
  if (data.record_id && env.AIRTABLE_API_KEY) {
    await updateAirtableRecord(env, data.record_id, { denied: true }).catch(
      (err) => console.error("Airtable update failed:", err)
    );
  }

  await fetch(responseUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      replace_original: true,
      text: `❌ *Denied* by @${adminUser} — ${data.email} will not be invited`,
    }),
  });
}

async function updateAirtableRecord(env, recordId, fields) {
  const table = encodeURIComponent(env.AIRTABLE_TABLE_NAME || "Table 1");
  const res = await fetch(
    `https://api.airtable.com/v0/${env.AIRTABLE_BASE_ID}/${table}/${recordId}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${env.AIRTABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    }
  );

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Airtable update failed (${res.status}): ${text}`);
  }
}

function inviteRequestBlocks({ email, name, chapter, recordId }) {
  return [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "💜 New Slack invite request",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        { type: "mrkdwn", text: `*Name:*\n${name || "_not provided_"}` },
        { type: "mrkdwn", text: `*Email:*\n${email}` },
        { type: "mrkdwn", text: `*Chapter:*\n${chapter || "_not provided_"}` },
        { type: "mrkdwn", text: `*Airtable ID:*\n\`${recordId || "n/a"}\`` },
      ],
    },
    {
      type: "actions",
      elements: [
        {
          type: "button",
          text: { type: "plain_text", text: "✓ Approve", emoji: true },
          style: "primary",
          action_id: "invite_approve",
          value: JSON.stringify({ email, name, record_id: recordId }),
        },
        {
          type: "button",
          text: { type: "plain_text", text: "✗ Deny", emoji: true },
          style: "danger",
          action_id: "invite_deny",
          value: JSON.stringify({ email, name, record_id: recordId }),
        },
      ],
    },
  ];
}

function approvalChecklistBlocks(email, approver, recordId) {
  return [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "✅ Approved — invite this person",
        emoji: true,
      },
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `Approved by *@${approver}*. Send the invite manually:\n\n  1. Open the workspace menu (top-left).\n  2. Choose *Invite people to RLadies+*.\n  3. Paste this email and send:`,
      },
    },
    {
      type: "section",
      text: { type: "mrkdwn", text: `\`${email}\`` },
    },
    {
      type: "actions",
      elements: [
        {
          type: "button",
          text: { type: "plain_text", text: "✓ Mark invite sent", emoji: true },
          style: "primary",
          action_id: "invite_mark_sent",
          value: JSON.stringify({
            email,
            record_id: recordId,
            approver,
          }),
        },
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: "Click *Mark invite sent* once the invite has been delivered — that flips the Airtable record.",
        },
      ],
    },
  ];
}
