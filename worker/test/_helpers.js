import { vi } from "vitest";

export function makeKv(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    async get(key, mode) {
      if (!store.has(key)) return null;
      const raw = store.get(key);
      if (mode === "json") return JSON.parse(raw);
      return raw;
    },
    async put(key, value) {
      store.set(key, typeof value === "string" ? value : JSON.stringify(value));
    },
    async delete(key) {
      store.delete(key);
    },
    _dump() {
      return Object.fromEntries(store);
    },
  };
}

export function makeD1(initialRows = []) {
  const rows = initialRows.map((r, i) => ({
    id: r.id ?? i + 1,
    day: r.day ?? "",
    question: r.question ?? "",
    outcome: r.outcome ?? "answered",
    top_score: r.top_score ?? null,
    sources: r.sources ?? null,
    up: r.up ?? 0,
    down: r.down ?? 0,
  }));
  let nextId = rows.reduce((max, r) => Math.max(max, r.id), 0) + 1;

  function prepare(sql) {
    const upper = sql.trim().toUpperCase();
    let bound = [];
    const stmt = {
      bind(...args) {
        bound = args;
        return stmt;
      },
      async run() {
        if (upper.startsWith("INSERT")) {
          const [day, question, outcome, top_score, sources] = bound;
          const row = {
            id: nextId++,
            day,
            question,
            outcome,
            top_score,
            sources,
            up: 0,
            down: 0,
          };
          rows.push(row);
          return { success: true, meta: { last_row_id: row.id, changes: 1 } };
        }
        if (upper.startsWith("UPDATE")) {
          const id = bound[bound.length - 1];
          const row = rows.find((r) => r.id === id);
          if (!row) return { success: true, meta: { changes: 0 } };
          if (/UP\s*=\s*UP\s*\+/.test(upper)) row.up += 1;
          if (/DOWN\s*=\s*DOWN\s*\+/.test(upper)) row.down += 1;
          return { success: true, meta: { changes: 1 } };
        }
        if (upper.startsWith("DELETE")) {
          const cutoff = bound[0];
          const before = rows.length;
          for (let i = rows.length - 1; i >= 0; i--) {
            if (rows[i].day < cutoff) rows.splice(i, 1);
          }
          return { success: true, meta: { changes: before - rows.length } };
        }
        return { success: true, meta: {} };
      },
      async all() {
        let results = rows.slice();
        if (/DAY\s*>=\s*\?/.test(upper) && bound.length) {
          const since = bound[0];
          results = results.filter((r) => r.day >= since);
        }
        return { success: true, results: results.map((r) => ({ ...r })) };
      },
      async first() {
        const { results } = await stmt.all();
        return results[0] || null;
      },
    };
    return stmt;
  }

  return { prepare, _rows: rows };
}

export function makeCtx() {
  const waits = [];
  return {
    waitUntil(p) {
      waits.push(Promise.resolve(p).catch(() => {}));
    },
    async flush() {
      await Promise.all(waits);
    },
  };
}

export function makeEnv(overrides = {}) {
  return {
    SLACK_SIGNING_SECRET: "test-signing-secret",
    SLACK_CLIENT_ID: "test-client-id",
    SLACK_CLIENT_SECRET: "test-client-secret",
    SLACK_ORGANIZER_TEAM_ID: "T_ORG",
    SLACK_COMMUNITY_TEAM_ID: "T_COM",
    SLACK_COMMUNITY_INVITE_CHANNEL: "C_INVITES",
    AIRTABLE_WEBHOOK_SECRET: "test-airtable-secret",
    AIRTABLE_API_KEY: "test-airtable-key",
    GITHUB_REPO: "rladies/jinx",
    GITHUB_TOKEN: "test-gh-token",
    JINX_API_KEY: "test-jinx-api-key",
    CLOUDFLARE_API_TOKEN: "test-cf-api-token",
    SLACK_TOKENS: makeKv(),
    AIRTABLE_BASES: makeKv(),
    SHORT_LINKS: makeKv(),
    ...overrides,
  };
}

export async function signSlack(secret, timestamp, body) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    enc.encode(`v0:${timestamp}:${body}`)
  );
  const hex = [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `v0=${hex}`;
}

export function mockFetch(handler) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
    const url = typeof input === "string" ? input : input.url;
    return handler(url, init || {});
  });
}

export function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
