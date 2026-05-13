const AIRTABLE_META_BASES_URL = "https://api.airtable.com/v0/meta/bases";
const ALLOWED_BASES_CACHE_KEY = "allowed_bases";
const ALLOWED_BASES_TTL_SECONDS = 3600;

export async function airtable_base_is_allowed(env, baseId) {
  if (!baseId) return false;
  const allowed = await airtable_allowed_bases_get(env);
  return allowed.has(baseId);
}

async function airtable_allowed_bases_get(env) {
  if (!env.AIRTABLE_BASES) {
    throw new Error("AIRTABLE_BASES KV binding not configured");
  }

  const cached = await env.AIRTABLE_BASES.get(ALLOWED_BASES_CACHE_KEY, "json");
  if (cached?.bases) {
    return new Set(cached.bases);
  }

  const ids = await airtable_meta_bases_fetch(env);
  await env.AIRTABLE_BASES.put(
    ALLOWED_BASES_CACHE_KEY,
    JSON.stringify({ bases: [...ids], fetched_at: new Date().toISOString() }),
    { expirationTtl: ALLOWED_BASES_TTL_SECONDS }
  );
  return ids;
}

async function airtable_meta_bases_fetch(env) {
  if (!env.AIRTABLE_API_KEY) {
    throw new Error("AIRTABLE_API_KEY not configured");
  }

  const ids = new Set();
  let offset;
  do {
    const url = new URL(AIRTABLE_META_BASES_URL);
    if (offset) url.searchParams.set("offset", offset);

    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${env.AIRTABLE_API_KEY}` },
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Airtable Meta API failed (${res.status}): ${text}`);
    }
    const data = await res.json();
    for (const base of data.bases || []) {
      ids.add(base.id);
    }
    offset = data.offset;
  } while (offset);

  return ids;
}
