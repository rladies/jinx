import { describe, it, expect, vi, afterEach } from "vitest";
import {
  invite_gateway_handle,
  invite_verify_handle,
  invite_redeem_handle,
  invite_send,
  invite_mark_joined,
  invite_pipeline_start,
  invite_start_handle,
  JOIN_HOST,
  _internals,
} from "../src/invite-gateway.js";
import { makeEnv, makeKv, makeCtx, mockFetch, jsonResponse } from "./_helpers.js";

afterEach(() => vi.restoreAllMocks());

// A KV seeded with the community bot token so slack_message_post / lookups work.
function seededEnv(overrides = {}) {
  return makeEnv({
    SLACK_TOKENS: makeKv({
      "team:T_COM": JSON.stringify({ bot_token: "xoxb-test", bot_user_id: "U1" }),
    }),
    ...overrides,
  });
}

// Records fetch traffic and returns configurable responses.
function fakeFetch({ member = null, records = [] } = {}) {
  const calls = { patches: [], creates: [], posts: [], gets: [] };
  mockFetch(async (url, init) => {
    const method = init.method || "GET";
    if (url.includes("users.lookupByEmail")) {
      return member
        ? jsonResponse({ ok: true, user: member })
        : jsonResponse({ ok: false, error: "users_not_found" });
    }
    if (url.includes("chat.postMessage")) {
      calls.posts.push(JSON.parse(init.body));
      return jsonResponse({ ok: true, ts: "1.0" });
    }
    if (url.includes("api.airtable.com")) {
      if (method === "PATCH") {
        calls.patches.push({ url, fields: JSON.parse(init.body).fields });
        return jsonResponse({ id: "recX", fields: {} });
      }
      if (method === "POST") {
        calls.creates.push(JSON.parse(init.body).fields);
        return jsonResponse({ id: "recNEW", fields: {} });
      }
      calls.gets.push(url);
      return jsonResponse({ records });
    }
    return jsonResponse({ ok: true });
  });
  return calls;
}

const master = (over = {}) => ({ url: "https://join.slack.com/t/x/shared_invite/zt-1", cap: 400, used: 0, ...over });

const jreq = (t, init) => new Request(`https://${JOIN_HOST}/j/${t}`, init);

describe("invite_verify_handle", () => {
  it("stamps verified, deletes the token, and confirms", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "verify:tok1": JSON.stringify({ record_id: "recP", email: "a@example.com" }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
    });
    const calls = fakeFetch();
    const ctx = makeCtx();

    const res = await invite_verify_handle(env, ctx, "tok1");
    expect(res.status).toBe(200);

    // token consumed
    expect(await env.INVITE_TOKENS.get("verify:tok1")).toBe(null);
    // verified stamp written
    const verify = calls.patches.find((p) => p.fields["Email verified on"]);
    expect(verify.fields.Stage).toBe("Verified");

    await ctx.flush();
    // clean guard → invite minted
    const invited = calls.patches.find((p) => p.fields["Invite link"]);
    expect(invited.fields.Stage).toBe("Invited");
    expect(invited.fields["Invite link"]).toContain(`https://${JOIN_HOST}/j/`);
  });

  it("returns 410 for an unknown token", async () => {
    const env = seededEnv();
    fakeFetch();
    const res = await invite_verify_handle(env, makeCtx(), "nope");
    expect(res.status).toBe(410);
  });

  it("shows a request-an-invite button on dead-end pages when a form url is set", async () => {
    const env = seededEnv({ INVITE_FORM_URL: "https://airtable.com/shrTEST" });
    fakeFetch();
    const res = await invite_verify_handle(env, makeCtx(), "nope");
    expect(res.status).toBe(410);
    const html = await res.text();
    expect(html).toContain("https://airtable.com/shrTEST");
    expect(html).toContain("Request an invite");
  });

  it("holds a request from an existing member and does not mint an invite", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "verify:tok2": JSON.stringify({ record_id: "recP", email: "member@example.com" }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
    });
    const calls = fakeFetch({ member: { id: "U9" } });
    const ctx = makeCtx();

    await invite_verify_handle(env, ctx, "tok2");
    await ctx.flush();

    expect(calls.patches.some((p) => p.fields.Stage === "Held")).toBe(true);
    expect(calls.patches.some((p) => p.fields["Invite link"])).toBe(false);
    expect(calls.posts.length).toBeGreaterThan(0); // alert posted
  });

  it("keeps the token for retry if the Airtable stamp fails", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "verify:tokF": JSON.stringify({ record_id: "recP", email: "a@example.com" }),
      }),
    });
    mockFetch(async (url) =>
      url.includes("api.airtable.com")
        ? jsonResponse({ error: "boom" }, 500)
        : jsonResponse({ ok: true }),
    );
    const res = await invite_verify_handle(env, makeCtx(), "tokF");
    expect(res.status).toBe(503);
    expect(await env.INVITE_TOKENS.get("verify:tokF")).not.toBe(null);
  });
});

describe("invite_send", () => {
  it("mints a token and writes the invite link when budget remains", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({ [_internals.MASTER_KEY]: JSON.stringify(master()) }),
    });
    const calls = fakeFetch();
    const url = await invite_send(env, "recP", "a@example.com");
    expect(url).toContain(`https://${JOIN_HOST}/j/`);

    const token = url.split("/j/")[1];
    const stored = await env.INVITE_TOKENS.get(`token:${token}`, "json");
    expect(stored).toMatchObject({ record_id: "recP", uses_left: _internals.INVITE_MAX_USES });
    expect(calls.patches[0].fields.Stage).toBe("Invited");
  });

  it("holds and alerts when the budget is exhausted", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({ [_internals.MASTER_KEY]: JSON.stringify(master({ used: 400 })) }),
    });
    const calls = fakeFetch();
    const url = await invite_send(env, "recP", "a@example.com");
    expect(url).toBe(null);
    expect(calls.patches[0].fields.Stage).toBe("Held");
    expect(calls.posts.length).toBe(1);
  });
});

describe("invite_redeem_handle", () => {
  it("302-redirects to the master link and decrements uses", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "token:red1": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 3 }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
    });
    const calls = fakeFetch();
    const ctx = makeCtx();

    const res = await invite_redeem_handle(env, ctx, jreq("red1"), "red1");
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe(master().url);

    const stored = await env.INVITE_TOKENS.get("token:red1", "json");
    expect(stored.uses_left).toBe(2);

    await ctx.flush();
    const clicked = calls.patches.find((p) => p.fields["Link clicked on"]);
    expect(clicked.fields.Stage).toBe("Clicked");
    const bumped = await env.INVITE_TOKENS.get(_internals.MASTER_KEY, "json");
    expect(bumped.used).toBe(1);
  });

  it("returns 410 when the token is used up", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "token:dead": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 0 }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
    });
    fakeFetch();
    const res = await invite_redeem_handle(env, makeCtx(), jreq("dead"), "dead");
    expect(res.status).toBe(410);
  });

  it("returns 503 when the master link is unset", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "token:red2": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 3 }),
      }),
    });
    fakeFetch();
    const res = await invite_redeem_handle(env, makeCtx(), jreq("red2"), "red2");
    expect(res.status).toBe(503);
  });
});

describe("invite budget alert", () => {
  const redeemEnv = (masterOver) =>
    seededEnv({
      INVITE_TOKENS: makeKv({
        "token:b": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 3 }),
        [_internals.MASTER_KEY]: JSON.stringify(master(masterOver)),
      }),
    });

  it("alerts once when usage crosses the low threshold (even on overshoot)", async () => {
    // used 355 -> 356; remaining 44 <= 50. Exact-equality on 50 would miss this.
    const env = redeemEnv({ used: 355 });
    const calls = fakeFetch();
    const ctx = makeCtx();
    await invite_redeem_handle(env, ctx, jreq("b"), "b");
    await ctx.flush();
    expect(calls.posts.length).toBe(1);
    const m = await env.INVITE_TOKENS.get(_internals.MASTER_KEY, "json");
    expect(m.low_alerted).toBe(true);
    expect(m.used).toBe(356);
  });

  it("does not re-alert once low_alerted is set", async () => {
    const env = redeemEnv({ used: 380, low_alerted: true });
    const calls = fakeFetch();
    const ctx = makeCtx();
    await invite_redeem_handle(env, ctx, jreq("b"), "b");
    await ctx.flush();
    expect(calls.posts.length).toBe(0);
  });
});

describe("turnstile gate", () => {
  const tsEnv = (over = {}) =>
    seededEnv({
      TURNSTILE_SECRET: "ts-secret",
      TURNSTILE_SITE_KEY: "ts-site-key",
      INVITE_TOKENS: makeKv({
        "token:t1": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 3 }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
      ...over,
    });

  it("shows a challenge page on GET and does not consume the token", async () => {
    const env = tsEnv();
    fakeFetch();
    const res = await invite_redeem_handle(env, makeCtx(), jreq("t1"), "t1");
    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain("challenges.cloudflare.com/turnstile");
    expect(html).toContain("ts-site-key");
    expect((await env.INVITE_TOKENS.get("token:t1", "json")).uses_left).toBe(3);
  });

  it("redirects on POST when the turnstile token verifies", async () => {
    const env = tsEnv();
    mockFetch(async (url) =>
      url.includes("siteverify")
        ? jsonResponse({ success: true })
        : jsonResponse({ id: "recX", fields: {} }),
    );
    const body = new URLSearchParams({ "cf-turnstile-response": "good" });
    const res = await invite_redeem_handle(env, makeCtx(), jreq("t1", { method: "POST", body }), "t1");
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe(master().url);
    expect((await env.INVITE_TOKENS.get("token:t1", "json")).uses_left).toBe(2);
  });

  it("rejects a POST when turnstile fails and keeps the token unused", async () => {
    const env = tsEnv();
    mockFetch(async (url) =>
      url.includes("siteverify") ? jsonResponse({ success: false }) : jsonResponse({ ok: true }),
    );
    const body = new URLSearchParams({ "cf-turnstile-response": "bad" });
    const res = await invite_redeem_handle(env, makeCtx(), jreq("t1", { method: "POST", body }), "t1");
    expect(res.status).toBe(403);
    expect((await env.INVITE_TOKENS.get("token:t1", "json")).uses_left).toBe(3);
  });
});

describe("invite_mark_joined", () => {
  it("stamps Joined on when an email matches a pipeline row", async () => {
    const env = seededEnv();
    const calls = fakeFetch({ records: [{ id: "recP", fields: { email: "a@e.com" } }] });
    const ok = await invite_mark_joined(env, "a@e.com");
    expect(ok).toBe(true);
    expect(calls.patches[0].fields["Joined on"]).toBeTruthy();
    expect(calls.patches[0].fields.Stage).toBe("Joined");
  });

  it("returns false when there is no matching row", async () => {
    const env = seededEnv();
    fakeFetch({ records: [] });
    expect(await invite_mark_joined(env, "ghost@e.com")).toBe(false);
    expect(await invite_mark_joined(env, "")).toBe(false);
  });
});

describe("invite_pipeline_start", () => {
  it("creates a pipeline row and stores a verify token", async () => {
    const env = seededEnv();
    const calls = fakeFetch();
    const { recordId, verifyUrl } = await invite_pipeline_start(env, {
      email: "new@e.com",
      submissionRecordId: "recSub",
    });
    expect(recordId).toBe("recNEW");
    expect(verifyUrl).toContain(`https://${JOIN_HOST}/verify/`);
    expect(calls.creates[0]).toMatchObject({ email: "new@e.com", Stage: "Verifying", Submission: ["recSub"] });

    const token = verifyUrl.split("/verify/")[1];
    const stored = await env.INVITE_TOKENS.get(`verify:${token}`, "json");
    expect(stored).toMatchObject({ record_id: "recNEW", email: "new@e.com" });
  });
});

describe("guards", () => {
  it("flags disposable domains", () => {
    const env = seededEnv();
    expect(_internals.is_disposable(env, "x@mailinator.com")).toBe(true);
    expect(_internals.is_disposable(env, "x@gmail.com")).toBe(false);
    expect(_internals.is_disposable(env, "no-at-sign")).toBe(true);
  });

  it("honours an env blocklist extension", () => {
    const env = seededEnv({ INVITE_BLOCKLIST_DOMAINS: "bad.test, evil.example" });
    expect(_internals.is_disposable(env, "x@bad.test")).toBe(true);
  });
});

describe("invite_start_handle", () => {
  it("rejects a bad secret", async () => {
    const env = seededEnv();
    const req = new Request("https://x/invite/start", {
      method: "POST",
      headers: { "x-airtable-secret": "wrong" },
      body: JSON.stringify({ email: "a@e.com" }),
    });
    const res = await invite_start_handle(req, env);
    expect(res.status).toBe(401);
  });

  it("rejects a malformed email", async () => {
    const env = seededEnv();
    fakeFetch();
    const req = new Request("https://x/invite/start", {
      method: "POST",
      headers: { "x-airtable-secret": env.AIRTABLE_WEBHOOK_SECRET },
      body: JSON.stringify({ email: "not-an-email" }),
    });
    const res = await invite_start_handle(req, env);
    expect(res.status).toBe(400);
  });

  it("starts the pipeline for a valid request", async () => {
    const env = seededEnv();
    const calls = fakeFetch();
    const req = new Request("https://x/invite/start", {
      method: "POST",
      headers: { "x-airtable-secret": env.AIRTABLE_WEBHOOK_SECRET },
      body: JSON.stringify({ email: "a@e.com", submission_record_id: "recSub" }),
    });
    const res = await invite_start_handle(req, env);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.verify_url).toContain(`https://${JOIN_HOST}/verify/`);
    expect(calls.creates.length).toBe(1);
  });
});

describe("invite_gateway_handle routing", () => {
  it("routes /verify and /j and 404s the rest", async () => {
    const env = seededEnv({
      INVITE_TOKENS: makeKv({
        "token:r": JSON.stringify({ record_id: "recP", email: "a@e.com", uses_left: 3 }),
        [_internals.MASTER_KEY]: JSON.stringify(master()),
      }),
    });
    fakeFetch();
    const root = await invite_gateway_handle(env, makeCtx(), new Request(`https://${JOIN_HOST}/`));
    expect(root.status).toBe(200);
    const redeem = await invite_gateway_handle(env, makeCtx(), new Request(`https://${JOIN_HOST}/j/r`));
    expect(redeem.status).toBe(302);
    const missing = await invite_gateway_handle(env, makeCtx(), new Request(`https://${JOIN_HOST}/wat/x`));
    expect(missing.status).toBe(404);
  });
});
