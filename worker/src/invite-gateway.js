// Masked Slack-invite gateway, backed by the INVITE_TOKENS KV namespace.
//
// The real ("master") Slack invite link is never emailed or stored in Airtable
// -- it lives only at KV key `config:master_invite_link`. Applicants instead
// receive per-person tokenised URLs on the `join.rladies.org` host:
//
//   /verify/<token>  double opt-in: proves the applicant owns the email before
//                    any invite is minted. Stamps `Email verified on`.
//   /j/<token>       redeems an invite: 302-redirects to the master link,
//                    single-use-ish (limited uses + TTL) so a forwarded link is
//                    near-useless. Stamps `Link clicked on` and bumps the
//                    master link's usage against its finite cap.
//
// Token entries carry the Airtable *pipeline* record they act on, so the same
// handlers work regardless of which base/table the pipeline lives in.
import { slack_message_post, slack_user_lookup_by_email } from "./slack-api.js";

export const JOIN_HOST = "join.rladies.org";

const MASTER_KEY = "config:master_invite_link";
const VERIFY_PREFIX = "verify:";
const INVITE_PREFIX = "token:";

const TOKEN_ALPHABET =
  "23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ";
const TOKEN_LENGTH = 22;

const VERIFY_TTL_SECONDS = 7 * 24 * 60 * 60;
const INVITE_TTL_SECONDS = 72 * 60 * 60;
const INVITE_MAX_USES = 3;
const BUDGET_ALERT_REMAINING = 50; // alert organisers when this many invites left

const DEFAULT_DISPOSABLE_DOMAINS = new Set([
  "mailinator.com",
  "guerrillamail.com",
  "10minutemail.com",
  "yopmail.com",
  "throwawaymail.com",
  "trashmail.com",
  "getnada.com",
  "temp-mail.org",
  "tempmail.com",
  "sharklasers.com",
  "dispostable.com",
  "maildrop.cc",
  "fakeinbox.com",
  "mailnesia.com",
  "mintemail.com",
]);

// --- routing -------------------------------------------------------------

export async function invite_gateway_handle(env, ctx, request) {
  const url = new URL(request.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const [section, token] = parts;

  if (!section) {
    return html_page(
      "RLadies+ Slack",
      "Nothing to see here — this is the RLadies+ Slack join gateway. 🔮",
      200,
    );
  }
  if (section === "verify" && token && request.method === "GET") {
    return invite_verify_handle(env, ctx, token);
  }
  if (section === "j" && token) {
    return invite_redeem_handle(env, ctx, request, token);
  }
  return html_page("Not found", "That link doesn't lead anywhere.", 404);
}

// --- verify (double opt-in) ---------------------------------------------

export async function invite_verify_handle(env, ctx, token) {
  const entry = await env.INVITE_TOKENS.get(VERIFY_PREFIX + token, "json").catch(
    () => null,
  );
  if (!entry) {
    return html_page(
      "Link expired",
      "This confirmation link has expired or was already used. Please submit the join form again.",
      410,
    );
  }

  await env.INVITE_TOKENS.delete(VERIFY_PREFIX + token).catch(() => {});
  await pipeline_update(env, entry.record_id, {
    "Email verified on": today(),
    Stage: "Verified",
  }).catch((e) => console.error("verify: pipeline update failed:", e));

  // Minting the invite (guards + Slack lookup + Airtable write) happens after
  // we respond, so the applicant sees a fast confirmation page.
  ctx.waitUntil(
    invite_after_verify(env, entry).catch((e) =>
      console.error("verify: post-verify processing failed:", e),
    ),
  );

  return html_page(
    "Email confirmed",
    "✅ Thanks — your email is confirmed. Your invitation to the RLadies+ Community Slack is on its way; check your inbox shortly. 💜",
    200,
  );
}

async function invite_after_verify(env, entry) {
  const guard = await guard_check(env, entry.email);
  if (!guard.ok) {
    await pipeline_update(env, entry.record_id, { Stage: "Held" });
    await alert(
      env,
      `:warning: Held for review — join request from \`${entry.email}\` (${guard.reason}). Approve or deny in the pipeline.`,
    );
    return;
  }
  await invite_send(env, entry.record_id, entry.email);
}

// --- invite send ---------------------------------------------------------

export async function invite_send(env, recordId, email) {
  const master = await master_link_get(env);
  if (!master || remaining(master) <= 0) {
    await pipeline_update(env, recordId, { Stage: "Held" });
    await alert(
      env,
      ":rotating_light: Invite link budget exhausted (or unset) — regenerate the Slack invite link and update the `config:master_invite_link` KV value. New invites are paused until then.",
    );
    return null;
  }

  const token = random_token();
  await env.INVITE_TOKENS.put(
    INVITE_PREFIX + token,
    JSON.stringify({
      record_id: recordId,
      email,
      uses_left: INVITE_MAX_USES,
    }),
    { expirationTtl: INVITE_TTL_SECONDS },
  );

  const inviteUrl = `https://${JOIN_HOST}/j/${token}`;
  await pipeline_update(env, recordId, {
    "Invite link": inviteUrl,
    "Invite sent on": today(),
    Stage: "Invited",
  });
  return inviteUrl;
}

// --- redeem (redirect to the masked master link) -------------------------

export async function invite_redeem_handle(env, ctx, request, token) {
  const key = INVITE_PREFIX + token;
  const entry = await env.INVITE_TOKENS.get(key, "json").catch(() => null);
  if (!entry || (entry.uses_left ?? 0) <= 0) {
    return html_page(
      "Link expired",
      "This invitation link has expired or has already been used. Ask an organiser to re-send your invite.",
      410,
    );
  }

  const master = await master_link_get(env);
  if (!master?.url) {
    return html_page(
      "Temporarily unavailable",
      "We couldn't complete your invite right now. Please try again shortly, or contact an organiser.",
      503,
    );
  }

  // Bot gate (Cloudflare Turnstile), active only when a widget is configured.
  // When on: a GET shows the challenge and the redirect happens on the
  // POST-back after we verify the token server-side. When off: a GET redeems
  // directly, exactly as before -- so this is a no-op until the keys are set.
  const turnstileOn = env.TURNSTILE_SECRET && env.TURNSTILE_SITE_KEY;
  if (turnstileOn) {
    if (request.method !== "POST") {
      return turnstile_challenge_page(env, token);
    }
    const form = await request.formData().catch(() => null);
    const passed = await turnstile_verify(
      env,
      form?.get("cf-turnstile-response"),
      request,
    );
    if (!passed) {
      return html_page(
        "One more try",
        "We couldn't confirm you're human. Open your invitation link again to retry.",
        403,
      );
    }
  } else if (request.method !== "GET") {
    return html_page("Not found", "That link doesn't lead anywhere.", 404);
  }

  // Enforce single-use-ish: decrement before redirecting. KV has no
  // check-and-set, so this is best-effort under concurrency -- acceptable for
  // low-volume, human-paced redemptions.
  const usesLeft = (entry.uses_left ?? 0) - 1;
  await env.INVITE_TOKENS.put(
    key,
    JSON.stringify({ ...entry, uses_left: usesLeft }),
    { expirationTtl: INVITE_TTL_SECONDS },
  ).catch((e) => console.error("redeem: token decrement failed:", e));

  ctx.waitUntil(
    redeem_side_effects(env, entry, master).catch((e) =>
      console.error("redeem: side effects failed:", e),
    ),
  );

  return Response.redirect(master.url, 302);
}

async function redeem_side_effects(env, entry, master) {
  await pipeline_update(env, entry.record_id, {
    "Link clicked on": today(),
    Stage: "Clicked",
  }).catch((e) => console.error("redeem: clicked stamp failed:", e));

  const used = (master.used || 0) + 1;
  await master_link_put(env, { ...master, used });
  if (remaining({ ...master, used }) === BUDGET_ALERT_REMAINING) {
    await alert(
      env,
      `:hourglass_flowing_sand: The Slack invite link has ~${BUDGET_ALERT_REMAINING} uses left (${used}/${master.cap}). Regenerate it and update \`config:master_invite_link\` soon so invites don't lapse.`,
    );
  }
}

// --- join detection (called from the team_join event handler) ------------

export async function invite_mark_joined(env, email) {
  if (!email) return false;
  const record = await pipeline_find_by_email(env, email);
  if (!record) return false;
  await pipeline_update(env, record.id, {
    "Joined on": today(),
    Stage: "Joined",
  });
  return true;
}

// --- pipeline row creation (called from the Airtable webhook) ------------

export async function invite_pipeline_start(env, { email, submissionRecordId }) {
  const token = random_token();
  const verifyUrl = `https://${JOIN_HOST}/verify/${token}`;

  const fields = {
    email,
    Stage: "Verifying",
    "Verify link": verifyUrl,
  };
  if (submissionRecordId) fields.Submission = [submissionRecordId];

  const record = await pipeline_create(env, fields);
  await env.INVITE_TOKENS.put(
    VERIFY_PREFIX + token,
    JSON.stringify({ record_id: record.id, email }),
    { expirationTtl: VERIFY_TTL_SECONDS },
  );
  return { recordId: record.id, verifyUrl };
}

// Entry point the Airtable automation calls on a new submission. Verifies the
// shared Airtable secret (same one the /airtable/webhook uses), then starts the
// double opt-in pipeline. Additive: it doesn't touch the existing R-driven
// approval flow, so the two can coexist while switching over.
export async function invite_start_handle(request, env) {
  if (request.headers.get("x-airtable-secret") !== env.AIRTABLE_WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }
  const email = String(payload.email || "").trim();
  const submissionRecordId = payload.submission_record_id || payload.record_id || "";
  if (!email) return new Response("Missing email", { status: 400 });

  const { recordId, verifyUrl } = await invite_pipeline_start(env, {
    email,
    submissionRecordId,
  });
  return Response.json({ ok: true, record_id: recordId, verify_url: verifyUrl });
}

// --- guards --------------------------------------------------------------

async function guard_check(env, email) {
  if (is_disposable(env, email)) {
    return { ok: false, reason: "disposable email domain" };
  }
  try {
    const member = await slack_user_lookup_by_email(
      env,
      env.SLACK_COMMUNITY_TEAM_ID,
      email,
    );
    if (member) return { ok: false, reason: "already a workspace member" };
  } catch (e) {
    console.warn("guard: member lookup failed (allowing):", e.message);
  }
  return { ok: true };
}

function is_disposable(env, email) {
  const domain = String(email).split("@")[1]?.toLowerCase();
  if (!domain) return true;
  if (DEFAULT_DISPOSABLE_DOMAINS.has(domain)) return true;
  const extra = (env.INVITE_BLOCKLIST_DOMAINS || "")
    .split(",")
    .map((d) => d.trim().toLowerCase())
    .filter(Boolean);
  return extra.includes(domain);
}

// --- master link + budget ------------------------------------------------

async function master_link_get(env) {
  return env.INVITE_TOKENS.get(MASTER_KEY, "json").catch(() => null);
}

async function master_link_put(env, value) {
  await env.INVITE_TOKENS.put(
    MASTER_KEY,
    JSON.stringify({ ...value, updated_at: new Date().toISOString() }),
  );
}

function remaining(master) {
  return (master.cap ?? 0) - (master.used ?? 0);
}

// --- Airtable pipeline helpers ------------------------------------------

async function pipeline_update(env, recordId, fields) {
  const res = await fetch(
    `https://api.airtable.com/v0/${env.AIRTABLE_INVITE_BASE}/${env.AIRTABLE_INVITE_TABLE}/${recordId}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${env.AIRTABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    },
  );
  if (!res.ok) {
    throw new Error(`Airtable pipeline update failed (${res.status})`);
  }
  return res.json();
}

async function pipeline_create(env, fields) {
  const res = await fetch(
    `https://api.airtable.com/v0/${env.AIRTABLE_INVITE_BASE}/${env.AIRTABLE_INVITE_TABLE}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.AIRTABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields, typecast: true }),
    },
  );
  if (!res.ok) {
    throw new Error(`Airtable pipeline create failed (${res.status})`);
  }
  return res.json();
}

async function pipeline_find_by_email(env, email) {
  const formula = encodeURIComponent(
    `LOWER({email})='${String(email).toLowerCase().replace(/'/g, "\\'")}'`,
  );
  const res = await fetch(
    `https://api.airtable.com/v0/${env.AIRTABLE_INVITE_BASE}/${env.AIRTABLE_INVITE_TABLE}?filterByFormula=${formula}&maxRecords=1`,
    { headers: { Authorization: `Bearer ${env.AIRTABLE_API_KEY}` } },
  );
  if (!res.ok) return null;
  const data = await res.json();
  return data.records?.[0] || null;
}

// --- helpers -------------------------------------------------------------

async function alert(env, text) {
  const channel = env.SLACK_ALERTS_CHANNEL;
  if (!channel) return;
  await slack_message_post(env, env.SLACK_COMMUNITY_TEAM_ID, {
    channel,
    text,
  }).catch((e) => console.error("alert post failed:", e));
}

function random_token() {
  const bytes = crypto.getRandomValues(new Uint8Array(TOKEN_LENGTH));
  let out = "";
  for (const b of bytes) out += TOKEN_ALPHABET[b % TOKEN_ALPHABET.length];
  return out;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function turnstile_challenge_page(env, token) {
  const action = `/j/${encodeURIComponent(token)}`;
  const body = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>One quick check · RLadies+</title>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#faf8fb;
color:#241026;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.card{max-width:30rem;margin:1.5rem;padding:2rem 2.25rem;background:#fff;border:1px solid #e8e1ec;
border-radius:1rem;box-shadow:0 4px 16px rgba(36,16,38,.06);text-align:center}
h1{font-size:1.3rem;margin:0 0 .5rem;color:#562457}p{margin:0 0 1.25rem;color:#4a3f52;line-height:1.5}
.cf-turnstile{display:inline-block}</style></head>
<body><div class="card"><h1>Almost there 💜</h1>
<p>One quick check before we take you to the RLadies+ Community Slack.</p>
<form method="POST" action="${action}">
<div class="cf-turnstile" data-sitekey="${escape_html(env.TURNSTILE_SITE_KEY)}" data-callback="onOk"></div>
<noscript><p>Please enable JavaScript to continue.</p></noscript>
</form>
<script>function onOk(){document.forms[0].submit();}</script>
</div></body></html>`;
  return new Response(body, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

async function turnstile_verify(env, cfToken, request) {
  if (!cfToken) return false;
  const body = new URLSearchParams({
    secret: env.TURNSTILE_SECRET,
    response: String(cfToken),
  });
  const ip = request.headers.get("CF-Connecting-IP");
  if (ip) body.set("remoteip", ip);
  const res = await fetch(
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
  )
    .then((r) => r.json())
    .catch(() => null);
  return Boolean(res?.success);
}

function html_page(title, message, status) {
  const body = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape_html(title)} · RLadies+</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#faf8fb;
color:#241026;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.card{max-width:34rem;margin:1.5rem;padding:2rem 2.25rem;background:#fff;border:1px solid #e8e1ec;
border-radius:1rem;box-shadow:0 4px 16px rgba(36,16,38,.06)}
h1{font-size:1.4rem;margin:0 0 .5rem;color:#562457}p{margin:0;line-height:1.55;color:#4a3f52}</style>
</head><body><div class="card"><h1>${escape_html(title)}</h1><p>${escape_html(message)}</p></div></body></html>`;
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function escape_html(s) {
  return String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
}

export const _internals = {
  is_disposable,
  guard_check,
  master_link_get,
  master_link_put,
  remaining,
  random_token,
  MASTER_KEY,
  VERIFY_PREFIX,
  INVITE_PREFIX,
  INVITE_MAX_USES,
  BUDGET_ALERT_REMAINING,
};
