import { describe, it, expect, afterEach, vi } from "vitest";
import { slack_command_handle } from "../src/slash-command.js";
import { github_dispatch_send } from "../src/github-dispatch.js";
import { makeEnv, makeCtx } from "./_helpers.js";

vi.mock("../src/github-dispatch.js", () => ({
  github_dispatch_send: vi.fn(async () => undefined),
}));

afterEach(() => {
  vi.restoreAllMocks();
});

function makeBody(overrides = {}) {
  return new URLSearchParams({
    team_id: "T_ORG",
    text: "help",
    user_id: "U1",
    user_name: "alice",
    channel_id: "C1",
    channel_name: "general",
    response_url: "https://hooks.slack.com/r/test",
    ...overrides,
  }).toString();
}

describe("slack_command_handle", () => {
  it("returns help text on `/jinx help`", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response("# Helpful help", { status: 200 })
    );
    const res = await slack_command_handle(makeEnv(), makeCtx(), makeBody({ text: "help" }));
    const json = await res.json();
    expect(json.response_type).toBe("ephemeral");
    expect(json.text).toMatch(/Helpful help/);
  });

  it("falls back to a static message when help fetch fails", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response("nope", { status: 500 })
    );
    const res = await slack_command_handle(makeEnv(), makeCtx(), makeBody({ text: "help" }));
    const json = await res.json();
    expect(json.text).toMatch(/couldn't load the help text/);
  });

  it("returns help when text is empty", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response("# Help", { status: 200 })
    );
    const res = await slack_command_handle(makeEnv(), makeCtx(), makeBody({ text: "" }));
    const json = await res.json();
    expect(json.response_type).toBe("ephemeral");
  });

  it("refuses commands from workspaces not in the allowlist", async () => {
    const res = await slack_command_handle(
      makeEnv(),
      makeCtx(),
      makeBody({ team_id: "T_RANDOM" })
    );
    const json = await res.json();
    expect(json.response_type).toBe("ephemeral");
    expect(json.text).toMatch(/only runs in/i);
  });

  it("returns a Slack url_verification challenge unchanged", async () => {
    const body = new URLSearchParams({
      type: "url_verification",
      challenge: "abc123",
    }).toString();
    const res = await slack_command_handle(makeEnv(), makeCtx(), body);
    const json = await res.json();
    expect(json.challenge).toBe("abc123");
  });

  it("acks dispatched commands synchronously with a fun message", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response("{}", { status: 204 })
    );
    const env = makeEnv({
      JINX_APP_ID: "1",
      JINX_PRIVATE_KEY: "x",
    });
    const ctx = makeCtx();
    const res = await slack_command_handle(env, ctx, makeBody({ text: "report-weekly" }));
    const json = await res.json();
    expect(json.response_type).toBe("ephemeral");
    expect(json.text).toMatch(/report-weekly/);
  });

  it("includes team_id in the GitHub dispatch payload", async () => {
    const env = makeEnv({ JINX_APP_ID: "1", JINX_PRIVATE_KEY: "x" });
    const ctx = makeCtx();
    await slack_command_handle(
      env,
      ctx,
      makeBody({ team_id: "T_COM", text: "report-weekly" })
    );
    await ctx.flush();
    expect(github_dispatch_send).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ team_id: "T_COM", command: "report-weekly" })
    );
  });
});
