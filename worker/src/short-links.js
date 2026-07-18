// URL shortener backed by the SHORT_LINKS KV namespace (wrangler.jsonc).
// Key scheme: `code:<code>` -> {url, created_by, created_at}; `url:<url>` ->
// <code>, a reverse index so re-shortening the same destination always
// returns the existing code rather than minting a duplicate. The reverse
// index is the source of truth for "does this destination already have a
// short link" -- consulted even when the caller supplies a custom slug, so a
// conflicting slug request is rejected with a pointer to the existing code
// instead of creating a second link to the same place.
//
// Known gap: KV has no check-and-set, so two concurrent no-slug requests for
// a brand-new destination can race past the reverse-index check and each
// mint their own code. Acceptable here -- creation is low-volume and
// human/CI-driven, not a public high-throughput endpoint -- but worth
// revisiting (e.g. a Durable Object lock) if that usage pattern changes.
const CODE_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ";
const CODE_LENGTH = 7;
const CODE_GEN_ATTEMPTS = 5;
const SLUG_PATTERN = /^[a-zA-Z0-9_-]{3,32}$/;
const MAX_KV_KEY_BYTES = 512;
const MAX_CODE_LENGTH = 64;

export const SHORT_LINK_HOST = "l.rladies.org";

export class ShortLinkError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

export async function short_link_lookup(env, code) {
  if (!code || code.length > MAX_CODE_LENGTH) return null;
  const entry = await env.SHORT_LINKS.get(`code:${code}`, "json");
  return entry?.url || null;
}

export async function short_link_create(env, { url, slug, createdBy }) {
  const target = url_validate(url);
  const reverseKey = reverse_key_for(target);

  if (slug) {
    if (!SLUG_PATTERN.test(slug)) {
      throw new ShortLinkError(
        "Custom slugs must be 3-32 characters: letters, numbers, hyphens, or underscores only.",
        400,
      );
    }
    const existingSlugEntry = await env.SHORT_LINKS.get(`code:${slug}`, "json");
    if (existingSlugEntry) {
      if (existingSlugEntry.url === target) {
        return short_link_result(slug, target, false);
      }
      throw new ShortLinkError(`\`${slug}\` is already taken for a different link.`, 409);
    }
    const existingCode = reverseKey ? await env.SHORT_LINKS.get(reverseKey) : null;
    if (existingCode) {
      throw new ShortLinkError(
        `That link is already shortened as ${short_url(existingCode)} -- use that instead of creating a duplicate.`,
        409,
      );
    }
  } else {
    const existingCode = reverseKey ? await env.SHORT_LINKS.get(reverseKey) : null;
    if (existingCode) {
      return short_link_result(existingCode, target, false);
    }
  }

  const code = slug || (await random_unused_code(env));
  await write_link(env, code, target, createdBy, reverseKey);
  return short_link_result(code, target, true);
}

export async function short_link_redirect_handle(env, code) {
  if (!code) {
    return new Response(
      "Hi! I'm the Jinx link shortener. Nothing to see at the root. 🔮",
      { status: 200 },
    );
  }
  const target = await short_link_lookup(env, code);
  if (!target) {
    return new Response("Short link not found", { status: 404 });
  }
  return Response.redirect(target, 301);
}

export async function links_shorten_handle(request, env) {
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!payload || typeof payload !== "object" || !payload.url) {
    return new Response("url is required", { status: 400 });
  }
  const { url, slug } = payload;

  try {
    const result = await short_link_create(env, { url, slug, createdBy: "api" });
    return new Response(
      JSON.stringify({ code: result.code, url: result.url, short_url: result.shortUrl }),
      {
        status: result.created ? 201 : 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const status = err instanceof ShortLinkError ? err.status : 500;
    return new Response(err.message || "Failed to create short link", { status });
  }
}

function short_link_result(code, url, created) {
  return { code, url, shortUrl: short_url(code), created };
}

function short_url(code) {
  return `https://${SHORT_LINK_HOST}/${code}`;
}

function url_validate(rawUrl) {
  let parsed;
  try {
    parsed = new URL(String(rawUrl ?? "").trim());
  } catch {
    throw new ShortLinkError("That doesn't look like a valid URL.", 400);
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new ShortLinkError("Only http(s) URLs can be shortened.", 400);
  }
  return parsed.toString();
}

function reverse_key_for(url) {
  const key = `url:${url}`;
  return new TextEncoder().encode(key).length <= MAX_KV_KEY_BYTES ? key : null;
}

async function random_unused_code(env) {
  for (let attempt = 0; attempt < CODE_GEN_ATTEMPTS; attempt++) {
    const candidate = random_code();
    if (!(await env.SHORT_LINKS.get(`code:${candidate}`))) {
      return candidate;
    }
  }
  throw new ShortLinkError("Couldn't find a free short code -- try again.", 500);
}

function random_code() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  let code = "";
  for (const b of bytes) code += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return code;
}

async function write_link(env, code, url, createdBy, reverseKey) {
  const record = JSON.stringify({
    url,
    created_by: createdBy || null,
    created_at: new Date().toISOString(),
  });
  const writes = [env.SHORT_LINKS.put(`code:${code}`, record)];
  if (reverseKey) {
    writes.push(env.SHORT_LINKS.put(reverseKey, code));
  }
  await Promise.all(writes);
}
