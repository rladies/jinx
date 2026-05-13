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
    SLACK_TOKENS: makeKv(),
    AIRTABLE_BASES: makeKv(),
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
