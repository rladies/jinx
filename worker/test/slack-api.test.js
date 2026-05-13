import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  slack_signature_verify,
  slack_team_is_allowed,
  slack_token_get,
} from "../src/slack-api.js";
import { makeEnv, makeKv, signSlack } from "./_helpers.js";

describe("slack_signature_verify", () => {
  const secret = "test-secret";
  const body = "token=xxx&team_id=T_ORG&text=help";
  let now;

  beforeEach(() => {
    now = Math.floor(Date.now() / 1000);
  });

  it("accepts a valid signature with a fresh timestamp", async () => {
    const ts = String(now);
    const sig = await signSlack(secret, ts, body);
    expect(await slack_signature_verify(secret, ts, body, sig)).toBe(true);
  });

  it("rejects when the body has been tampered with", async () => {
    const ts = String(now);
    const sig = await signSlack(secret, ts, body);
    const tampered = body + "&extra=evil";
    expect(await slack_signature_verify(secret, ts, tampered, sig)).toBe(false);
  });

  it("rejects when the signing secret is wrong", async () => {
    const ts = String(now);
    const sig = await signSlack(secret, ts, body);
    expect(await slack_signature_verify("other-secret", ts, body, sig)).toBe(false);
  });

  it("rejects timestamps older than 5 minutes (replay protection)", async () => {
    const ts = String(now - 301);
    const sig = await signSlack(secret, ts, body);
    expect(await slack_signature_verify(secret, ts, body, sig)).toBe(false);
  });

  it("rejects when timestamp, signature, or secret is missing", async () => {
    expect(await slack_signature_verify(secret, null, body, "v0=abc")).toBe(false);
    expect(await slack_signature_verify(secret, "1", body, null)).toBe(false);
    expect(await slack_signature_verify(null, "1", body, "v0=abc")).toBe(false);
  });
});

describe("slack_team_is_allowed", () => {
  it("returns true for the organiser workspace", () => {
    const env = makeEnv();
    expect(slack_team_is_allowed(env, "T_ORG")).toBe(true);
  });

  it("returns true for the community workspace", () => {
    const env = makeEnv();
    expect(slack_team_is_allowed(env, "T_COM")).toBe(true);
  });

  it("returns false for an unknown workspace", () => {
    const env = makeEnv();
    expect(slack_team_is_allowed(env, "T_RANDOM")).toBe(false);
  });

  it("returns false when no team id is supplied", () => {
    const env = makeEnv();
    expect(slack_team_is_allowed(env, "")).toBe(false);
    expect(slack_team_is_allowed(env, null)).toBe(false);
  });

  it("throws when neither allowlist env var is configured", () => {
    const env = makeEnv({
      SLACK_ORGANIZER_TEAM_ID: undefined,
      SLACK_COMMUNITY_TEAM_ID: undefined,
    });
    expect(() => slack_team_is_allowed(env, "T_ORG")).toThrow(/refusing all installs/);
  });

  it("works with only the community workspace configured", () => {
    const env = makeEnv({ SLACK_ORGANIZER_TEAM_ID: undefined });
    expect(slack_team_is_allowed(env, "T_COM")).toBe(true);
    expect(slack_team_is_allowed(env, "T_ORG")).toBe(false);
  });
});

describe("slack_token_get", () => {
  it("returns the stored bot token for a known team", async () => {
    const env = makeEnv({
      SLACK_TOKENS: makeKv({
        "team:T_ORG": JSON.stringify({ bot_token: "xoxb-real-token" }),
      }),
    });
    expect(await slack_token_get(env, "T_ORG")).toBe("xoxb-real-token");
  });

  it("throws when no team id is supplied", async () => {
    const env = makeEnv();
    await expect(slack_token_get(env, "")).rejects.toThrow(/requires a team id/);
  });

  it("throws when the KV binding is missing", async () => {
    const env = makeEnv({ SLACK_TOKENS: undefined });
    await expect(slack_token_get(env, "T_ORG")).rejects.toThrow(/KV binding not configured/);
  });

  it("throws when no token has been stored for the team", async () => {
    const env = makeEnv();
    await expect(slack_token_get(env, "T_UNKNOWN")).rejects.toThrow(/No bot token for team/);
  });
});
