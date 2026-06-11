import { describe, it, expect, afterEach, vi } from "vitest";
import {
  slack_event_handle,
  slack_event_strip_mention,
} from "../src/slack-events.js";
import { makeEnv, makeCtx, makeKv, jsonResponse } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function makeEventBody(event, { teamId = "T_ORG" } = {}) {
  return JSON.stringify({ type: "event_callback", team_id: teamId, event });
}

describe("slack_event_handle", () => {
  it("returns the challenge for Slack's url_verification handshake", async () => {
    const res = await slack_event_handle(
      makeEnv(),
      makeCtx(),
      JSON.stringify({ type: "url_verification", challenge: "abc" })
    );
    const json = await res.json();
    expect(json.challenge).toBe("abc");
  });

  it("returns 400 for invalid JSON bodies", async () => {
    const res = await slack_event_handle(makeEnv(), makeCtx(), "not json");
    expect(res.status).toBe(400);
  });

  it("ignores event_callback envelopes for unknown event types", async () => {
    const res = await slack_event_handle(
      makeEnv(),
      makeCtx(),
      makeEventBody({ type: "channel_created", channel: { id: "C1" } })
    );
    expect(res.status).toBe(200);
  });

  it("ignores bot-authored DM messages to prevent loops", async () => {
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return jsonResponse({ ok: true });
    });
    const res = await slack_event_handle(
      makeEnv(),
      makeCtx(),
      makeEventBody({
        type: "message",
        channel_type: "im",
        channel: "D1",
        ts: "1.0",
        text: "hi",
        bot_id: "B1",
      })
    );
    expect(res.status).toBe(200);
    expect(calls.filter((c) => c.url.includes("chat.postMessage"))).toHaveLength(0);
  });

  it("ignores DM message subtypes (edits, joins, etc.) to prevent feedback loops", async () => {
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return jsonResponse({ ok: true });
    });
    const res = await slack_event_handle(
      makeEnv(),
      makeCtx(),
      makeEventBody({
        type: "message",
        channel_type: "im",
        channel: "D1",
        ts: "1.0",
        text: "edited",
        subtype: "message_changed",
        user: "U1",
      })
    );
    expect(res.status).toBe(200);
    expect(calls.filter((c) => c.url.includes("chat.postMessage"))).toHaveLength(0);
  });

  it("posts a refusal in-thread for app_mention from a non-allowlisted workspace", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_RANDOM": JSON.stringify({ bot_token: "xoxb-other" }),
      }),
    });
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
      calls.push({ url: typeof input === "string" ? input : input.url, init });
      return jsonResponse({ ok: true });
    });

    const ctx = makeCtx();
    const res = await slack_event_handle(
      env,
      ctx,
      makeEventBody(
        {
          type: "app_mention",
          channel: "C1",
          ts: "1.0",
          thread_ts: "1.0",
          text: "<@UBOT> hi",
          user: "U1",
        },
        { teamId: "T_RANDOM" }
      )
    );
    expect(res.status).toBe(200);
    await ctx.flush();

    const posts = calls.filter((c) => c.url.includes("chat.postMessage"));
    expect(posts).toHaveLength(1);
    const body = JSON.parse(posts[0].init.body);
    expect(body.text).toMatch(/only roam in/i);
    expect(body.thread_ts).toBe("1.0");
  });

  it("skips app_mention coming from a 1:1 DM-style channel id", async () => {
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      calls.push(typeof input === "string" ? input : input.url);
      return jsonResponse({ ok: true });
    });
    const res = await slack_event_handle(
      makeEnv(),
      makeCtx(),
      makeEventBody({
        type: "app_mention",
        channel: "D123",
        ts: "1.0",
        text: "<@UBOT> hi",
        user: "U1",
      })
    );
    expect(res.status).toBe(200);
    expect(calls.filter((u) => u.includes("chat.postMessage"))).toHaveLength(0);
  });

  it("acks team_join events from allowlisted workspaces with 200", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_ORG": JSON.stringify({ bot_token: "xoxb", bot_user_id: "B1" }),
      }),
    });
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      jsonResponse({ ok: true, channel: { id: "D1" } })
    );
    const res = await slack_event_handle(
      env,
      makeCtx(),
      makeEventBody({
        type: "team_join",
        user: { id: "U_NEW", profile: { email: "new@example.com" } },
      })
    );
    expect(res.status).toBe(200);
  });

  it("acks reaction_added events with 200 (and increments KV counters)", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_ORG": JSON.stringify({ bot_token: "xoxb", bot_user_id: "B1" }),
      }),
    });
    const ctx = makeCtx();
    const res = await slack_event_handle(
      env,
      ctx,
      makeEventBody({
        type: "reaction_added",
        reaction: "thumbsup",
        item: { type: "message", channel: "C1", ts: "1.0" },
        item_user: "B1",
      })
    );
    expect(res.status).toBe(200);
    await ctx.flush();
    const day = new Date().toISOString().slice(0, 10);
    const entry = await env.SLACK_TOKENS.get(
      `reaction_log:T_ORG:${day}:thumbsup`,
      "json"
    );
    expect(entry?.count).toBe(1);
  });

  it("does not count reactions on non-bot messages", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_ORG": JSON.stringify({ bot_token: "xoxb", bot_user_id: "B1" }),
      }),
    });
    const ctx = makeCtx();
    await slack_event_handle(
      env,
      ctx,
      makeEventBody({
        type: "reaction_added",
        reaction: "thumbsup",
        item: { type: "message", channel: "C1", ts: "1.0" },
        item_user: "U_OTHER",
      })
    );
    await ctx.flush();
    const day = new Date().toISOString().slice(0, 10);
    const entry = await env.SLACK_TOKENS.get(
      `reaction_log:T_ORG:${day}:thumbsup`,
      "json"
    );
    expect(entry).toBeNull();
  });
});

describe("slack_event_strip_mention", () => {
  it("strips bare user mentions", () => {
    expect(slack_event_strip_mention("hey <@U12345> ping")).toBe("hey  ping".trim());
  });

  it("strips user mentions that include a display name", () => {
    expect(slack_event_strip_mention("yo <@U12345|jinx> what's up")).toBe(
      "yo  what's up".trim(),
    );
  });

  it("strips subteam mentions", () => {
    expect(slack_event_strip_mention("cc <!subteam^S0123|coc-team>")).toBe("cc");
  });

  it("strips channel-wide mentions", () => {
    expect(slack_event_strip_mention("<!channel> heads up")).toBe(
      "heads up",
    );
    expect(slack_event_strip_mention("<!here> ping")).toBe("ping");
    expect(slack_event_strip_mention("<!everyone> woo")).toBe("woo");
  });
});
