import { describe, it, expect, afterEach, vi } from "vitest";
import {
  airtable_webhook_handle,
  pending_link_key,
  slack_interaction_handle,
} from "../src/airtable-invite.js";
import { makeEnv, makeCtx, makeKv, jsonResponse } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function airtableRequest(body, headers = {}) {
  return new Request("https://jinx.example.com/airtable/webhook", {
    method: "POST",
    headers: {
      "x-airtable-secret": "test-airtable-secret",
      "Content-Type": "application/json",
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function validRecordPayload(overrides = {}) {
  return {
    email: "new@example.com",
    name: "New Member",
    chapter: "Oslo",
    record_id: "rec0123456789ABCD",
    base_id: "app0123456789ABCD",
    table_id: "tbl0123456789ABCD",
    ...overrides,
  };
}

describe("airtable_webhook_handle", () => {
  it("returns 401 when the webhook secret header is missing or wrong", async () => {
    const env = makeEnv();
    const r1 = await airtable_webhook_handle(
      new Request("https://jinx.example.com/airtable/webhook", {
        method: "POST",
        body: JSON.stringify(validRecordPayload()),
      }),
      env
    );
    expect(r1.status).toBe(401);
    const r2 = await airtable_webhook_handle(
      airtableRequest(validRecordPayload(), { "x-airtable-secret": "wrong" }),
      env
    );
    expect(r2.status).toBe(401);
  });

  it("returns 500 when AIRTABLE_WEBHOOK_SECRET is not configured at all", async () => {
    const env = makeEnv({ AIRTABLE_WEBHOOK_SECRET: undefined });
    const res = await airtable_webhook_handle(
      airtableRequest(validRecordPayload()),
      env
    );
    expect(res.status).toBe(500);
  });

  it("returns 400 when required fields are missing", async () => {
    const env = makeEnv();
    const noEmail = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ email: "" })),
      env
    );
    expect(noEmail.status).toBe(400);

    const noIds = await airtable_webhook_handle(
      airtableRequest({ email: "x@y.z" }),
      env
    );
    expect(noIds.status).toBe(400);
  });

  it("returns 400 when Airtable IDs do not match the expected shape", async () => {
    const env = makeEnv();
    const badRec = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ record_id: "not-a-record" })),
      env
    );
    expect(badRec.status).toBe(400);

    const badBase = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ base_id: "BASE-NO" })),
      env
    );
    expect(badBase.status).toBe(400);

    const badTable = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ table_id: "TABLE-NO" })),
      env
    );
    expect(badTable.status).toBe(400);
  });

  it("returns 403 when the Airtable base is not in the PAT scope", async () => {
    const env = makeEnv({
      AIRTABLE_BASES: makeKv({
        allowed_bases: JSON.stringify({
          bases: [],
          fetched_at: new Date().toISOString(),
        }),
      }),
    });
    const res = await airtable_webhook_handle(
      airtableRequest(validRecordPayload()),
      env
    );
    expect(res.status).toBe(403);
  });

  it("posts an invite-request message to Slack when everything checks out", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_COM": JSON.stringify({ bot_token: "xoxb-test" }),
      }),
      AIRTABLE_BASES: makeKv({
        allowed_bases: JSON.stringify({
          bases: ["app0123456789ABCD"],
          fetched_at: new Date().toISOString(),
        }),
      }),
    });
    const posted = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      const url = typeof input === "string" ? input : input.url;
      if (url.includes("chat.postMessage")) {
        posted.push({ url, init });
        return jsonResponse({ ok: true });
      }
      return jsonResponse({ ok: true });
    });
    const res = await airtable_webhook_handle(
      airtableRequest(validRecordPayload()),
      env
    );
    expect(res.status).toBe(200);
    expect(posted).toHaveLength(1);
    const body = JSON.parse(posted[0].init.body);
    expect(body.channel).toBe("C_INVITES");
    expect(body.text).toMatch(/New Slack invite request/);
    expect(body.blocks).toBeTruthy();
    const actionIds = body.blocks
      .filter((b) => b.type === "actions")
      .flatMap((b) => b.elements.map((e) => e.action_id));
    expect(actionIds).toContain("invite_approve");
    expect(actionIds).toContain("invite_deny");
  });
});

describe("pending_link_key", () => {
  it("normalises case and whitespace", () => {
    expect(pending_link_key("  Foo@Bar.Com  ")).toBe("pending_link:foo@bar.com");
  });
});

describe("slack_interaction_handle", () => {
  function interactionBody(payload) {
    return new URLSearchParams({ payload: JSON.stringify(payload) }).toString();
  }

  it("refuses interactions from workspaces not on the allowlist", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return new Response("ok", { status: 200 });
    });

    const res = await slack_interaction_handle(
      env,
      ctx,
      interactionBody({
        type: "block_actions",
        team: { id: "T_RANDOM" },
        user: { username: "rando" },
        response_url: "https://hooks.slack.com/r/x",
        actions: [{ action_id: "invite_approve", value: "{}" }],
      })
    );
    expect(res.status).toBe(200);
    await ctx.flush();
    const refusal = calls.find((c) => c.url === "https://hooks.slack.com/r/x");
    expect(refusal).toBeTruthy();
    const body = JSON.parse(refusal.init.body);
    expect(body.text).toMatch(/only runs in/i);
  });

  it("dispatches approval actions through ctx.waitUntil", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return new Response("ok", { status: 200 });
    });
    const res = await slack_interaction_handle(
      env,
      ctx,
      interactionBody({
        type: "block_actions",
        team: { id: "T_COM" },
        user: { username: "admin" },
        response_url: "https://hooks.slack.com/r/approve",
        actions: [
          {
            action_id: "invite_approve",
            value: JSON.stringify({
              email: "new@example.com",
              record_id: "rec0123456789ABCD",
              base_id: "app0123456789ABCD",
              table_id: "tbl0123456789ABCD",
            }),
          },
        ],
      })
    );
    expect(res.status).toBe(200);
    await ctx.flush();
    const call = calls.find((c) => c.url === "https://hooks.slack.com/r/approve");
    expect(call).toBeTruthy();
    const body = JSON.parse(call.init.body);
    expect(body.text).toMatch(/Approved by @admin/);
  });

  it("ignores interaction payloads that are not block_actions", async () => {
    const res = await slack_interaction_handle(
      makeEnv(),
      makeCtx(),
      interactionBody({ type: "view_submission" })
    );
    expect(res.status).toBe(200);
  });
});
