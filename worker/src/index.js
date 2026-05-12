import { handleSlackEvent } from "./slack-events.js";

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") {
      return new Response("Hi! I'm the Jinx Slack bridge. Nothing to see here. 🔮", {
        status: 200,
      });
    }

    const body = await request.text();

    // Verify Slack request signature
    const timestamp = request.headers.get("x-slack-request-timestamp");
    const signature = request.headers.get("x-slack-signature");
    console.log("Received request", { timestamp: !!timestamp, signature: !!signature, hasSecret: !!env.SLACK_SIGNING_SECRET });

    if (!await verifySlackSignature(env.SLACK_SIGNING_SECRET, timestamp, body, signature)) {
      console.log("Signature verification failed");
      return new Response("Invalid signature", { status: 401 });
    }

    console.log("Signature verified");

    // Events API (app_mention, etc.) sends JSON; slash commands send form-encoded
    const contentType = request.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      return handleSlackEvent(env, ctx, body);
    }

    const params = new URLSearchParams(body);

    // Legacy URL verification path (Events API now handled above)
    if (params.get("type") === "url_verification") {
      return Response.json({ challenge: params.get("challenge") });
    }

    const command = (params.get("text") || "").trim();
    const userId = params.get("user_id") || "";
    const userName = params.get("user_name") || "";
    const channelId = params.get("channel_id") || "";
    const channelName = params.get("channel_name") || "";
    const responseUrl = params.get("response_url") || "";

    // Handle help directly — no need for the full R pipeline
    if (!command || command === "help") {
      const helpText = await fetchHelpText();
      return Response.json({
        response_type: "ephemeral",
        text: helpText,
      });
    }

    // Respond immediately to Slack with a random quip
    const ack = Response.json({
      response_type: "ephemeral",
      text: randomAck(command),
    });

    // Dispatch to GitHub, notify Slack if it fails
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

    // Let the dispatch complete after responding to Slack
    ctx.waitUntil(dispatchPromise);

    return ack;
  },
};

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
