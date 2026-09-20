import { describe, it, expect, vi, afterEach } from "vitest";
import {
  slack_is_organizer_workspace,
  slack_leadership_authorize,
} from "../src/authorize.js";
import { makeKv } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

const ORG_ENV = { SLACK_ORGANIZER_TEAM_ID: "T_ORG" };

describe("slack_is_organizer_workspace", () => {
  it("is true only for the configured organiser team id", () => {
    expect(slack_is_organizer_workspace(ORG_ENV, "T_ORG")).toBe(true);
    expect(slack_is_organizer_workspace(ORG_ENV, "T_COMMUNITY")).toBe(false);
  });

  it("is false when no organiser team id is configured", () => {
    expect(slack_is_organizer_workspace({}, "T_ORG")).toBe(false);
  });
});

describe("slack_leadership_authorize", () => {
  function mockUsersInfo(email) {
    return vi.spyOn(globalThis, "fetch").mockImplementation(
      async () =>
        new Response(JSON.stringify({ ok: true, user: { profile: { email } } }), {
          status: 200,
        }),
    );
  }
  const withTokens = (over = {}) => ({
    SLACK_TOKENS: makeKv({ "team:T_ORG": JSON.stringify({ bot_token: "xoxb" }) }),
    ...over,
  });

  it("allows the caller whose verified email matches the admin default", async () => {
    mockUsersInfo("leadership@rladies.org");
    const res = await slack_leadership_authorize(withTokens(), {
      teamId: "T_ORG",
      userId: "U1",
    });
    expect(res.ok).toBe(true);
  });

  it("matches case-insensitively and honours INVITE_ADMIN_EMAIL", async () => {
    mockUsersInfo("Boss@RLadies.org");
    const res = await slack_leadership_authorize(
      withTokens({ INVITE_ADMIN_EMAIL: "boss@rladies.org" }),
      { teamId: "T_ORG", userId: "U1" },
    );
    expect(res.ok).toBe(true);
  });

  it("denies a caller whose verified email does not match", async () => {
    mockUsersInfo("member@example.com");
    const res = await slack_leadership_authorize(withTokens(), {
      teamId: "T_ORG",
      userId: "U1",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/Leadership/i);
  });

  it("is unverifiable (not a denial) when the email can't be read", async () => {
    mockUsersInfo(undefined);
    const res = await slack_leadership_authorize(withTokens(), {
      teamId: "T_ORG",
      userId: "U1",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });

  it("fails closed (unverifiable) when the lookup throws", async () => {
    const res = await slack_leadership_authorize(
      {},
      { teamId: "T_ORG", userId: "U1" },
    );
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });
});
