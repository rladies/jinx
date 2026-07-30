import { describe, it, expect, vi, afterEach } from "vitest";
import {
  slack_global_team_authorize,
  slack_is_organizer_workspace,
  slack_leadership_authorize,
} from "../src/authorize.js";
import { makeKv } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function mockAirtable(pages) {
  const queue = [...pages];
  return vi.spyOn(globalThis, "fetch").mockImplementation(async () => {
    const page = queue.shift() || { records: [] };
    return new Response(JSON.stringify(page), { status: 200 });
  });
}

const ORG_ENV = { SLACK_ORGANIZER_TEAM_ID: "T_ORG", AIRTABLE_API_KEY: "k" };

describe("slack_is_organizer_workspace", () => {
  it("is true only for the configured organiser team id", () => {
    expect(slack_is_organizer_workspace(ORG_ENV, "T_ORG")).toBe(true);
    expect(slack_is_organizer_workspace(ORG_ENV, "T_COMMUNITY")).toBe(false);
  });

  it("is false when no organiser team id is configured", () => {
    expect(slack_is_organizer_workspace({}, "T_ORG")).toBe(false);
  });
});

describe("slack_global_team_authorize", () => {
  it("allows a member whose Slack user id is in the directory", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack_id: "U123" } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "U123",
    });
    expect(res.ok).toBe(true);
  });

  it("normalises case and whitespace on the id before matching", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack_id: "  u123 " } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "U123",
    });
    expect(res.ok).toBe(true);
  });

  it("denies a user id not in the directory", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack_id: "U123" } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "U999",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/global team/i);
  });

  it("queries the member directory by base + table id", async () => {
    let calledUrl;
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
      calledUrl = String(url);
      return new Response(
        JSON.stringify({ records: [{ fields: { organiser_slack_id: "U1" } }] }),
        { status: 200 },
      );
    });
    await slack_global_team_authorize(ORG_ENV, { teamId: "T_ORG", userId: "U1" });
    expect(calledUrl).toContain("appZjaV7eM0Y9FsHZ");
    expect(calledUrl).toContain("tblfFWklqjtGdBLiT");
  });

  it("refuses commands from a non-organiser workspace without lookup", async () => {
    const fetchSpy = mockAirtable([]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_COMMUNITY",
      userId: "U123",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/organisers workspace/i);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("denies a missing user id without a lookup", async () => {
    const fetchSpy = mockAirtable([]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "",
    });
    expect(res.ok).toBe(false);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("fails closed (unverifiable) when the directory cannot be read", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(
      async () => new Response("nope", { status: 500 }),
    );
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "U123",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });

  it("fails closed when no Airtable key is configured", async () => {
    const res = await slack_global_team_authorize(
      { SLACK_ORGANIZER_TEAM_ID: "T_ORG" },
      { teamId: "T_ORG", userId: "U123" },
    );
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });

  it("follows Airtable pagination across pages", async () => {
    mockAirtable([
      { records: [{ fields: { organiser_slack_id: "U1" } }], offset: "p2" },
      { records: [{ fields: { organiser_slack_id: "U2" } }] },
    ]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userId: "U2",
    });
    expect(res.ok).toBe(true);
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
