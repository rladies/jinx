import { slack_team_is_allowed } from "./slack-api.js";

const NONCE_COOKIE = "jinx_install_nonce";

export async function slack_oauth_install_handle(env, url) {
  const scopes = "chat:write,chat:write.public,commands";
  const redirectUri = `${url.origin}/slack/oauth`;

  const ts = Date.now().toString();
  const nonce = crypto.randomUUID();
  const hmac = await slack_oauth_hmac_state(
    env.SLACK_CLIENT_SECRET,
    `${ts}:${nonce}`
  );

  const authUrl = new URL("https://slack.com/oauth/v2/authorize");
  authUrl.searchParams.set("client_id", env.SLACK_CLIENT_ID);
  authUrl.searchParams.set("scope", scopes);
  authUrl.searchParams.set("redirect_uri", redirectUri);
  authUrl.searchParams.set("state", `${ts}:${nonce}:${hmac}`);

  return new Response(null, {
    status: 302,
    headers: {
      Location: authUrl.toString(),
      "Set-Cookie": `${NONCE_COOKIE}=${nonce}; Path=/slack/oauth; HttpOnly; Secure; SameSite=Lax; Max-Age=600`,
    },
  });
}

export async function slack_oauth_callback_handle(request, env) {
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

  const [ts, nonce, hmac] = state.split(":");
  if (!ts || !nonce || !hmac) {
    return new Response("Invalid state parameter", { status: 403 });
  }
  const cookieNonce = parseCookie(request.headers.get("Cookie"), NONCE_COOKIE);
  if (!cookieNonce || cookieNonce !== nonce) {
    return new Response("State/cookie mismatch", { status: 403 });
  }
  const expectedHmac = await slack_oauth_hmac_state(
    env.SLACK_CLIENT_SECRET,
    `${ts}:${nonce}`
  );
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
  const teamName = data.team?.name || "unknown";

  if (!slack_team_is_allowed(env, teamId)) {
    console.warn(
      `Rejected install attempt from team ${teamName} (${teamId}) — not in allowlist`
    );
    return new Response(
      "🚫 Jinx is only installable in the RLadies+ organisers and community workspaces.",
      { status: 403, headers: { "Content-Type": "text/plain" } }
    );
  }

  const tokenData = {
    bot_token: data.access_token,
    team_id: teamId,
    team_name: teamName,
    bot_user_id: data.bot_user_id,
    installed_at: new Date().toISOString(),
  };

  await env.SLACK_TOKENS.put(`team:${teamId}`, JSON.stringify(tokenData));
  console.log(`Slack app installed in ${teamName} (${teamId})`);

  return new Response(
    `🔮 Jinx installed successfully in ${teamName}! You can close this tab.`,
    { status: 200, headers: { "Content-Type": "text/plain" } }
  );
}

async function slack_oauth_hmac_state(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function parseCookie(header, name) {
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === name) return v.join("=");
  }
  return null;
}
