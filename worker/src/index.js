export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // GET /slack/install — start OAuth flow
    // GET /slack/oauth — OAuth callback
    if (url.pathname === "/slack/install") {
      return handleSlackInstall(env, url);
    }
    if (url.pathname === "/slack/oauth") {
      return handleSlackOAuthCallback(request, env);
    }

    if (request.method !== "POST") {
      return new Response("Hi! I'm the Jinx Slack bridge. Nothing to see here. 🔮", {
        status: 200,
      });
    }

    // POST /slack/command — slash commands from Slack
    // POST /slack/interact — button clicks from Slack
    // POST /airtable/webhook — form submissions from Airtable
    if (url.pathname === "/slack/command") {
      return handleSlashCommand(request, env, ctx);
    }
    if (url.pathname === "/slack/interact") {
      return handleSlackInteraction(request, env, ctx);
    }
    if (url.pathname === "/airtable/webhook") {
      return handleAirtableWebhook(request, env);
    }

    return new Response("Not found", { status: 404 });
  },
};

async function handleSlashCommand(request, env, ctx) {
    const body = await request.text();
    const params = new URLSearchParams(body);

    const timestamp = request.headers.get("x-slack-request-timestamp");
    const signature = request.headers.get("x-slack-signature");
    console.log("Received request", { timestamp: !!timestamp, signature: !!signature, hasSecret: !!env.SLACK_SIGNING_SECRET });

    if (!await verifySlackSignature(env.SLACK_SIGNING_SECRET, timestamp, body, signature)) {
      console.log("Signature verification failed");
      return new Response("Invalid signature", { status: 401 });
    }

    console.log("Signature verified");

    if (params.get("type") === "url_verification") {
      return Response.json({ challenge: params.get("challenge") });
    }

    const command = (params.get("text") || "").trim();
    const userId = params.get("user_id") || "";
    const userName = params.get("user_name") || "";
    const channelId = params.get("channel_id") || "";
    const channelName = params.get("channel_name") || "";
    const responseUrl = params.get("response_url") || "";

    if (!command || command === "help") {
      const helpText = await fetchHelpText();
      return Response.json({
        response_type: "ephemeral",
        text: helpText,
      });
    }

    const ack = Response.json({
      response_type: "ephemeral",
      text: randomAck(command),
    });

    const dispatchPromise = dispatchToGitHub(env, {
      command,
      user_id: userId,
      user_name: userName,
      channel_id: channelId,
      channel_name: channelName,
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

const WAIT_NOTE = "\n_This may take a couple of minutes — Jinx will reply here when done._";

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

async function dispatchToGitHub(env, payload) {
  const token = await mintInstallationToken(env);

  const response = await fetch(
    `https://api.github.com/repos/${env.GITHUB_REPO}/dispatches`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: JSON.stringify({
        event_type: "slack-command",
        client_payload: payload,
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    console.error(`GitHub dispatch failed (${response.status}): ${text}`);
  }
}

async function mintInstallationToken(env) {
  const jwt = await createJWT(env.JINX_APP_ID, env.JINX_PRIVATE_KEY);

  // Find the installation for the rladies org
  const installRes = await fetch(
    `https://api.github.com/app/installations`,
    {
      headers: {
        Authorization: `Bearer ${jwt}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
      },
    }
  );

  if (!installRes.ok) {
    throw new Error(`Failed to list installations: ${installRes.status}`);
  }

  const installations = await installRes.json();
  const installation = installations.find(
    (i) => i.account?.login?.toLowerCase() === "rladies"
  );

  if (!installation) {
    throw new Error("No installation found for rladies org");
  }

  // Create an installation access token
  const tokenRes = await fetch(
    `https://api.github.com/app/installations/${installation.id}/access_tokens`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${jwt}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
      },
    }
  );

  if (!tokenRes.ok) {
    throw new Error(`Failed to create installation token: ${tokenRes.status}`);
  }

  const { token } = await tokenRes.json();
  return token;
}

async function createJWT(appId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iat: now - 60,
    exp: now + 600,
    iss: appId,
  };

  const enc = new TextEncoder();
  const b64url = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64 = b64url(header);
  const payloadB64 = b64url(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await importPrivateKey(privateKeyPem);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    enc.encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

async function importPrivateKey(pem) {
  const pemContents = pem
    .replace(/-----BEGIN RSA PRIVATE KEY-----/, "")
    .replace(/-----END RSA PRIVATE KEY-----/, "")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  // Try PKCS8 first, fall back to PKCS1
  try {
    return await crypto.subtle.importKey(
      "pkcs8",
      binaryDer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );
  } catch {
    // PKCS1 keys need to be wrapped in PKCS8 — GitHub apps usually use PKCS1
    // Re-throw with a helpful message
    throw new Error(
      "Private key import failed. Ensure JINX_PRIVATE_KEY is in PEM format (PKCS8). " +
      "Convert with: openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in key.pem -out key-pkcs8.pem"
    );
  }
}

// --- Slack OAuth flow ---

async function handleSlackInstall(env, url) {
  const scopes = "chat:write,chat:write.public,commands";
  const redirectUri = `${url.origin}/slack/oauth`;

  const ts = Date.now().toString();
  const state = await hmacState(env.SLACK_CLIENT_SECRET, ts);

  const authUrl = new URL("https://slack.com/oauth/v2/authorize");
  authUrl.searchParams.set("client_id", env.SLACK_CLIENT_ID);
  authUrl.searchParams.set("scope", scopes);
  authUrl.searchParams.set("redirect_uri", redirectUri);
  authUrl.searchParams.set("state", `${ts}:${state}`);

  return Response.redirect(authUrl.toString(), 302);
}

async function handleSlackOAuthCallback(request, env) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const error = url.searchParams.get("error");

  if (error) {
    return new Response(`Installation cancelled: ${error}`, { status: 400 });
  }
  if (!code || !state) {
    return new Response("Missing code or state", { status: 400 });
  }

  const [ts, hmac] = state.split(":");
  const expectedHmac = await hmacState(env.SLACK_CLIENT_SECRET, ts);
  if (hmac !== expectedHmac) {
    return new Response("Invalid state parameter", { status: 403 });
  }
  if (Date.now() - parseInt(ts) > 600_000) {
    return new Response("State expired", { status: 403 });
  }

  const redirectUri = `${url.origin}/slack/oauth`;

  const tokenRes = await fetch("https://slack.com/api/oauth.v2.access", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: env.SLACK_CLIENT_ID,
      client_secret: env.SLACK_CLIENT_SECRET,
      code,
      redirect_uri: redirectUri,
    }),
  });

  const data = await tokenRes.json();
  if (!data.ok) {
    console.error("OAuth token exchange failed:", data.error);
    return new Response(`OAuth failed: ${data.error}`, { status: 502 });
  }

  const teamId = data.team?.id;
  const tokenData = {
    bot_token: data.access_token,
    team_id: teamId,
    team_name: data.team?.name || "unknown",
    bot_user_id: data.bot_user_id,
    installed_at: new Date().toISOString(),
  };

  await env.SLACK_TOKENS.put(`team:${teamId}`, JSON.stringify(tokenData));
  console.log(`Slack app installed in ${tokenData.team_name} (${teamId})`);

  return new Response(
    `🔮 Jinx installed successfully in ${tokenData.team_name}! You can close this tab.`,
    { status: 200, headers: { "Content-Type": "text/plain" } }
  );
}

async function hmacState(secret, timestamp) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(timestamp));
  return btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function getSlackToken(env, teamId) {
  if (teamId) {
    const data = await env.SLACK_TOKENS.get(`team:${teamId}`, "json");
    if (data?.bot_token) return data.bot_token;
  }

  if (env.SLACK_COMMUNITY_TOKEN) {
    console.warn("Using legacy SLACK_COMMUNITY_TOKEN — complete OAuth install to remove this fallback");
    return env.SLACK_COMMUNITY_TOKEN;
  }

  throw new Error(`No Slack token found for team ${teamId}`);
}

// --- Airtable → Slack invite approval flow ---

async function handleAirtableWebhook(request, env) {
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

  const blocks = [
    {
      type: "header",
      text: { type: "plain_text", text: "💜 New Slack invite request", emoji: true },
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

async function handleSlackInteraction(request, env, ctx) {
  const body = await request.text();
  const params = new URLSearchParams(body);

  const timestamp = request.headers.get("x-slack-request-timestamp");
  const signature = request.headers.get("x-slack-signature");

  if (!await verifySlackSignature(env.SLACK_SIGNING_SECRET, timestamp, body, signature)) {
    return new Response("Invalid signature", { status: 401 });
  }

  let interaction;
  try {
    interaction = JSON.parse(params.get("payload"));
  } catch {
    return new Response("Invalid payload", { status: 400 });
  }

  if (interaction.type !== "block_actions") {
    return new Response("OK", { status: 200 });
  }

  const action = interaction.actions?.[0];
  if (!action) return new Response("OK", { status: 200 });

  const actionData = JSON.parse(action.value);
  const adminUser = interaction.user?.username || "unknown";
  const responseUrl = interaction.response_url;

  if (action.action_id === "invite_approve") {
    ctx.waitUntil(processApproval(env, actionData, adminUser, responseUrl));
  } else if (action.action_id === "invite_deny") {
    ctx.waitUntil(processDenial(env, actionData, adminUser, responseUrl));
  }

  return new Response("", { status: 200 });
}

async function processApproval(env, data, adminUser, responseUrl) {
  try {
    await dispatchToGitHub(env, {
      command: `slack-invite ${data.email}`,
      user_name: adminUser,
      channel_id: env.SLACK_INVITE_CHANNEL,
      channel_name: "invite-requests",
      response_url: responseUrl,
    });

    if (data.record_id && env.AIRTABLE_API_KEY) {
      await updateAirtableRecord(env, data.record_id, { invited: true });
    }

    await fetch(responseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        replace_original: true,
        text: `✅ *Approved* by @${adminUser} — invite dispatched to ${data.email}`,
      }),
    });
  } catch (err) {
    console.error("Approval processing failed:", err);
    await fetch(responseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        replace_original: false,
        text: `😿 Approval failed for ${data.email}: ${err.message}`,
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
  const res = await fetch(
    `https://api.airtable.com/v0/${env.AIRTABLE_BASE_ID}/${encodeURIComponent(env.AIRTABLE_TABLE_NAME || "Table 1")}/${recordId}`,
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

async function verifySlackSignature(signingSecret, timestamp, body, expected) {
  if (!timestamp || !expected || !signingSecret) return false;

  // Reject requests older than 5 minutes
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

  const computed = `v0=${hex}`;
  return computed === expected;
}
