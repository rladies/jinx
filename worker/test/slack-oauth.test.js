import { describe, it, expect, afterEach, vi } from "vitest";
import {
  slack_oauth_install_handle,
  slack_oauth_callback_handle,
} from "../src/slack-oauth.js";
import { makeEnv, makeKv, jsonResponse } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("slack_oauth_install_handle", () => {
  it("issues a 302 to slack.com/oauth/v2/authorize with the required scopes and a signed state", async () => {
    const env = makeEnv();
    const url = new URL("https://jinx.example.com/slack/install");
    const res = await slack_oauth_install_handle(env, url);
    expect(res.status).toBe(302);

    const location = new URL(res.headers.get("Location"));
    expect(location.origin + location.pathname).toBe(
      "https://slack.com/oauth/v2/authorize"
    );
    expect(location.searchParams.get("client_id")).toBe("test-client-id");
    expect(location.searchParams.get("redirect_uri")).toBe(
      "https://jinx.example.com/slack/oauth"
    );

    const state = location.searchParams.get("state") || "";
    const parts = state.split(":");
    expect(parts).toHaveLength(3);
    const [ts, nonce, hmac] = parts;
    expect(Number(ts)).toBeGreaterThan(0);
    expect(nonce.length).toBeGreaterThan(10);
    expect(hmac.length).toBeGreaterThan(10);

    const cookie = res.headers.get("Set-Cookie");
    expect(cookie).toContain(`jinx_install_nonce=${nonce}`);
    expect(cookie).toContain("HttpOnly");
    expect(cookie).toContain("Secure");
  });

  it("emits scopes Slack needs for the Assistant + welcome flows", async () => {
    const env = makeEnv();
    const url = new URL("https://jinx.example.com/slack/install");
    const res = await slack_oauth_install_handle(env, url);
    const scopes =
      new URL(res.headers.get("Location")).searchParams.get("scope") || "";
    for (const expected of [
      "assistant:write",
      "im:history",
      "im:write",
      "users:read.email",
      "team:read",
      "reactions:read",
      "reactions:write",
      "bookmarks:read",
      "bookmarks:write",
      "channels:join",
    ]) {
      expect(scopes.split(",")).toContain(expected);
    }
  });
});

describe("slack_oauth_callback_handle", () => {
  async function makeCallback(env, { code = "good-code", stateOverride, cookieNonce } = {}) {
    const installRes = await slack_oauth_install_handle(
      env,
      new URL("https://jinx.example.com/slack/install")
    );
    const location = new URL(installRes.headers.get("Location"));
    const state = stateOverride ?? location.searchParams.get("state");
    const nonceForCookie = cookieNonce ?? state.split(":")[1];
    return new Request(
      `https://jinx.example.com/slack/oauth?code=${code}&state=${encodeURIComponent(state)}`,
      {
        headers: { Cookie: `jinx_install_nonce=${nonceForCookie}` },
      }
    );
  }

  it("rejects requests missing code or state", async () => {
    const env = makeEnv();
    const res = await slack_oauth_callback_handle(
      new Request("https://jinx.example.com/slack/oauth"),
      env
    );
    expect(res.status).toBe(400);
  });

  it("propagates Slack's own `error` param", async () => {
    const env = makeEnv();
    const res = await slack_oauth_callback_handle(
      new Request("https://jinx.example.com/slack/oauth?error=access_denied"),
      env
    );
    expect(res.status).toBe(400);
    expect(await res.text()).toMatch(/access_denied/);
  });

  it("rejects when the cookie nonce does not match the state nonce", async () => {
    const env = makeEnv();
    const req = await makeCallback(env, { cookieNonce: "wrong-nonce" });
    const res = await slack_oauth_callback_handle(req, env);
    expect(res.status).toBe(403);
    expect(await res.text()).toMatch(/State\/cookie mismatch/);
  });

  it("rejects when the HMAC in state is tampered with", async () => {
    const env = makeEnv();
    const installRes = await slack_oauth_install_handle(
      env,
      new URL("https://jinx.example.com/slack/install")
    );
    const state = new URL(installRes.headers.get("Location")).searchParams.get("state");
    const [ts, nonce] = state.split(":");
    const tamperedState = `${ts}:${nonce}:tampered-hmac`;
    const req = new Request(
      `https://jinx.example.com/slack/oauth?code=x&state=${encodeURIComponent(tamperedState)}`,
      { headers: { Cookie: `jinx_install_nonce=${nonce}` } }
    );
    const res = await slack_oauth_callback_handle(req, env);
    expect(res.status).toBe(403);
  });

  it("rejects installs from workspaces not on the allowlist", async () => {
    const env = makeEnv();
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = typeof input === "string" ? input : input.url;
      if (url.includes("oauth.v2.access")) {
        return jsonResponse({
          ok: true,
          access_token: "xoxb-test",
          bot_user_id: "B1",
          team: { id: "T_RANDOM", name: "Random Workspace" },
        });
      }
      return jsonResponse({ ok: true });
    });
    const req = await makeCallback(env);
    const res = await slack_oauth_callback_handle(req, env);
    expect(res.status).toBe(403);
    expect(await res.text()).toMatch(/only installable/);
  });

  it("persists the bot token in KV when an allowlisted workspace installs", async () => {
    const env = makeEnv({ SLACK_TOKENS: makeKv() });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = typeof input === "string" ? input : input.url;
      if (url.includes("oauth.v2.access")) {
        return jsonResponse({
          ok: true,
          access_token: "xoxb-real",
          bot_user_id: "B123",
          team: { id: "T_ORG", name: "RLadies+ Organisers" },
        });
      }
      if (url.includes("team.info")) {
        return jsonResponse({
          ok: true,
          team: { name: "RLadies+ Organisers", domain: "rladies", icon: {} },
        });
      }
      return jsonResponse({ ok: true });
    });
    const req = await makeCallback(env);
    const res = await slack_oauth_callback_handle(req, env);
    expect(res.status).toBe(200);
    const stored = await env.SLACK_TOKENS.get("team:T_ORG", "json");
    expect(stored.bot_token).toBe("xoxb-real");
    expect(stored.bot_user_id).toBe("B123");
    expect(stored.team_domain).toBe("rladies");
  });

  it("surfaces a 502 when Slack rejects the OAuth code exchange", async () => {
    const env = makeEnv();
    vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      jsonResponse({ ok: false, error: "invalid_code" })
    );
    const req = await makeCallback(env);
    const res = await slack_oauth_callback_handle(req, env);
    expect(res.status).toBe(502);
    expect(await res.text()).toMatch(/invalid_code/);
  });
});
