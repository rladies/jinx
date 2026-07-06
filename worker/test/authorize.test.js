import { describe, it, expect, vi, afterEach } from "vitest";
import { slack_global_team_authorize } from "../src/authorize.js";

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

describe("slack_global_team_authorize", () => {
  it("allows a directory member in the organiser workspace", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack: "alice" } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userName: "alice",
    });
    expect(res.ok).toBe(true);
  });

  it("normalises @, case, and whitespace before matching", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack: "  @Alice " } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userName: "ALICE",
    });
    expect(res.ok).toBe(true);
  });

  it("denies an actor not in the directory", async () => {
    mockAirtable([{ records: [{ fields: { organiser_slack: "alice" } }] }]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userName: "mallory",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/global team/i);
  });

  it("refuses commands from a non-organiser workspace without lookup", async () => {
    const fetchSpy = mockAirtable([]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_COMMUNITY",
      userName: "alice",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/organisers workspace/i);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("fails closed (unverifiable) when the directory cannot be read", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(
      async () => new Response("nope", { status: 500 }),
    );
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userName: "alice",
    });
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });

  it("fails closed when no Airtable key is configured", async () => {
    const res = await slack_global_team_authorize(
      { SLACK_ORGANIZER_TEAM_ID: "T_ORG" },
      { teamId: "T_ORG", userName: "alice" },
    );
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/try again/i);
  });

  it("follows Airtable pagination across pages", async () => {
    mockAirtable([
      { records: [{ fields: { organiser_slack: "alice" } }], offset: "p2" },
      { records: [{ fields: { organiser_slack: "bob" } }] },
    ]);
    const res = await slack_global_team_authorize(ORG_ENV, {
      teamId: "T_ORG",
      userName: "bob",
    });
    expect(res.ok).toBe(true);
  });
});
