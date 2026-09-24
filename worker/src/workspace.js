// Creates chapter mailboxes in Google Workspace via the Admin SDK Directory
// API.
//
// WHY THIS IS JAVASCRIPT AND MUST STAY THAT WAY
//
// jinx is deliberately migrating worker logic into the R package - the
// removed /analytics/rum route is the pattern: an R function replaced a
// worker endpoint outright. This module is the documented exception, and the
// reason is the credential, not the code.
//
// R could do all of this. openssl::signature_create(data, sha256, key)
// produces exactly the RSASSA-PKCS1-v1_5 signature RS256 needs, so the whole
// flow is roughly forty lines of httr2. Nothing here is hard in R.
//
// But porting it moves WORKSPACE_SA_PRIVATE_KEY to where the R code runs,
// which is a GitHub Actions runner. That key impersonates a Workspace admin
// and can create accounts in the rladies.org domain. Keeping it as a
// Cloudflare secret means a leaked GitHub token reaches nothing: the most a
// caller holding JINX_WORKER_API_KEY can do is ask for a mailbox whose name
// survives the validation below.
//
// So: code location follows key location. If you are porting worker modules
// to R, skip this one. If the key ever moves into a protected GitHub
// environment as a deliberate decision, this module can follow it - the R
// interface, chapter_mailbox_create(), is already the only caller and its
// signature would not change.
//
// The generated password is deliberately never returned to the caller. The
// Directory API requires one at creation, but handing it back would put a
// live credential into CI logs and issue comments; the account is created
// with changePasswordAtNextLogin and the onboarding team issues the real
// handover from the Admin console.
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const USERS_URL = "https://admin.googleapis.com/admin/directory/v1/users";
const SCOPE = "https://www.googleapis.com/auth/admin.directory.user";

// Bounded at both ends so a name can neither start nor end with a hyphen,
// and capped well short of the 64-character local-part limit.
const LOCAL_PART = /^[a-z0-9](?:[a-z0-9-]{1,30})[a-z0-9]$/;

// Names that must never be claimed by a chapter, whatever a request says.
const RESERVED = new Set([
  "abuse",
  "admin",
  "administrator",
  "billing",
  "chapters",
  "help",
  "hostmaster",
  "info",
  "jinx",
  "leadership",
  "mail",
  "no-reply",
  "noreply",
  "postmaster",
  "root",
  "security",
  "support",
  "webmaster",
]);

export class WorkspaceError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

export function mailbox_local_part(city) {
  const slug = String(city || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  if (!LOCAL_PART.test(slug)) {
    throw new WorkspaceError(`Not a usable mailbox name: ${city}`, 400);
  }
  if (RESERVED.has(slug)) {
    throw new WorkspaceError(`${slug} is a reserved address`, 400);
  }
  return slug;
}

function base64url(bytes) {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pem_to_bytes(pem) {
  const body = String(pem || "")
    .replace(/-----[A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  if (!body) throw new WorkspaceError("Service account key is not configured", 500);
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function signed_assertion(env, now) {
  const claims = {
    iss: env.WORKSPACE_SA_EMAIL,
    sub: env.WORKSPACE_SUBJECT,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  if (!claims.iss || !claims.sub) {
    throw new WorkspaceError("Workspace impersonation is not configured", 500);
  }

  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const payload = base64url(new TextEncoder().encode(JSON.stringify(claims)));
  const signingInput = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pem_to_bytes(env.WORKSPACE_SA_PRIVATE_KEY),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(signature)}`;
}

export async function workspace_token(env, now = Math.floor(Date.now() / 1000)) {
  const assertion = await signed_assertion(env, now);
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.access_token) {
    throw new WorkspaceError("Workspace token exchange failed", 502);
  }
  return body.access_token;
}

// 32 bytes of CSPRNG output, rendered as hex. Never logged, never returned.
function throwaway_password() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export async function mailbox_create(env, { city, givenName, familyName }) {
  const localPart = mailbox_local_part(city);
  const domain = env.WORKSPACE_DOMAIN || "rladies.org";
  const email = `${localPart}@${domain}`;

  const token = await workspace_token(env);
  const response = await fetch(USERS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      primaryEmail: email,
      name: {
        givenName: givenName || "RLadies+",
        familyName: familyName || city,
      },
      password: throwaway_password(),
      changePasswordAtNextLogin: true,
      orgUnitPath: env.WORKSPACE_OU || "/Chapters",
    }),
  });

  if (response.status === 409) {
    throw new WorkspaceError(`${email} already exists`, 409);
  }
  if (!response.ok) {
    // The API's own message can quote the request, so it is not echoed back.
    console.warn(`Directory API rejected ${email}: ${response.status}`);
    throw new WorkspaceError("Workspace rejected the mailbox creation", 502);
  }

  return { email, orgUnitPath: env.WORKSPACE_OU || "/Chapters" };
}

export async function workspace_mailbox_handle(request, env) {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const payload = await request.json().catch(() => null);
  if (!payload?.city) {
    return new Response(JSON.stringify({ error: "city is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const created = await mailbox_create(env, payload);
    return new Response(JSON.stringify(created), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const status = err instanceof WorkspaceError ? err.status : 500;
    return new Response(JSON.stringify({ error: err.message }), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  }
}
