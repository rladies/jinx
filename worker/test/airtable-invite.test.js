import { describe, it, expect, afterEach, vi } from "vitest";
vi.mock("../src/github-dispatch.js", () => ({
  github_dispatch_send: vi.fn(async () => undefined),
}));
import { github_dispatch_send } from "../src/github-dispatch.js";
import {
  airtable_webhook_handle,
  slack_interaction_handle,
} from "../src/airtable-invite.js";
import { makeEnv, makeCtx } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
  github_dispatch_send.mockClear();
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
    const ctx = makeCtx();
    const r1 = await airtable_webhook_handle(
      new Request("https://jinx.example.com/airtable/webhook", {
        method: "POST",
        body: JSON.stringify(validRecordPayload()),
      }),
      env,
      ctx
    );
    expect(r1.status).toBe(401);
    const r2 = await airtable_webhook_handle(
      airtableRequest(validRecordPayload(), { "x-airtable-secret": "wrong" }),
      env,
      ctx
    );
    expect(r2.status).toBe(401);
  });

  it("returns 500 when AIRTABLE_WEBHOOK_SECRET is not configured at all", async () => {
    const env = makeEnv({ AIRTABLE_WEBHOOK_SECRET: undefined });
    const res = await airtable_webhook_handle(
      airtableRequest(validRecordPayload()),
      env,
      makeCtx()
    );
    expect(res.status).toBe(500);
  });

  it("returns 400 when required fields are missing", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const noEmail = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ email: "" })),
      env,
      ctx
    );
    expect(noEmail.status).toBe(400);

    const noIds = await airtable_webhook_handle(
      airtableRequest({ email: "x@y.z" }),
      env,
      ctx
    );
    expect(noIds.status).toBe(400);
  });

  it("returns 400 when Airtable IDs do not match the expected shape", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const badRec = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ record_id: "not-a-record" })),
      env,
      ctx
    );
    expect(badRec.status).toBe(400);

    const badBase = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ base_id: "BASE-NO" })),
      env,
      ctx
    );
    expect(badBase.status).toBe(400);

    const badTable = await airtable_webhook_handle(
      airtableRequest(validRecordPayload({ table_id: "TABLE-NO" })),
      env,
      ctx
    );
    expect(badTable.status).toBe(400);
  });

  it("dispatches a slack-event for a validated webhook, without checking the base allowlist itself", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const res = await airtable_webhook_handle(
      airtableRequest(validRecordPayload()),
      env,
      ctx
    );
    expect(res.status).toBe(200);
    await ctx.flush();
    expect(github_dispatch_send).toHaveBeenCalledWith(
      env,
      "slack-event",
      expect.objectContaining({
        kind: "airtable_webhook",
        event: {
          email: "new@example.com",
          name: "New Member",
          chapter: "Oslo",
          record_id: "rec0123456789ABCD",
          base_id: "app0123456789ABCD",
          table_id: "tbl0123456789ABCD",
        },
      })
    );
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
    expect(body.text).toMatch(/only roam in/i);
    expect(github_dispatch_send).not.toHaveBeenCalled();
  });

  it("posts a Processing placeholder and dispatches the interaction", async () => {
    const env = makeEnv();
    const ctx = makeCtx();
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return new Response("ok", { status: 200 });
    });
    const actionValue = {
      email: "new@example.com",
      record_id: "rec0123456789ABCD",
      base_id: "app0123456789ABCD",
      table_id: "tbl0123456789ABCD",
    };
    const res = await slack_interaction_handle(
      env,
      ctx,
      interactionBody({
        type: "block_actions",
        team: { id: "T_COM" },
        user: { username: "admin" },
        response_url: "https://hooks.slack.com/r/approve",
        actions: [{ action_id: "invite_approve", value: JSON.stringify(actionValue) }],
      })
    );
    expect(res.status).toBe(200);
    await ctx.flush();

    const ack = calls.find((c) => c.url === "https://hooks.slack.com/r/approve");
    expect(ack).toBeTruthy();
    const ackBody = JSON.parse(ack.init.body);
    expect(ackBody.replace_original).toBe(true);
    expect(ackBody.text).toMatch(/Processing/);

    expect(github_dispatch_send).toHaveBeenCalledWith(
      env,
      "slack-event",
      expect.objectContaining({
        kind: "slack_interaction",
        team_id: "T_COM",
        response_url: "https://hooks.slack.com/r/approve",
        event: {
          action_id: "invite_approve",
          action_data: actionValue,
          admin_user: "admin",
        },
      })
    );
  });

  it("ignores interaction payloads that are not block_actions", async () => {
    const res = await slack_interaction_handle(
      makeEnv(),
      makeCtx(),
      interactionBody({ type: "view_submission" })
    );
    expect(res.status).toBe(200);
    expect(github_dispatch_send).not.toHaveBeenCalled();
  });
});
