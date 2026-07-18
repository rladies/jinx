import { describe, it, expect, vi, afterEach } from "vitest";
import {
  command_requires_global_team,
  command_requires_organizer_workspace,
  slash_local_handle,
} from "../src/slash-local.js";
import { makeKv } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("command_requires_global_team", () => {
  it("flags the question/feedback surfaces", () => {
    expect(command_requires_global_team("questions 30")).toBe(true);
    expect(command_requires_global_team("feedback")).toBe(true);
  });

  it("leaves the rest open", () => {
    expect(command_requires_global_team("pair @a @b")).toBe(false);
    expect(command_requires_global_team("remind-me later | x")).toBe(false);
  });
});

describe("slash_local_handle global-team gate", () => {
  function run(command, { env, params }) {
    const posts = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      if (typeof url === "string" && url.includes("hooks.slack.com")) {
        posts.push(JSON.parse(init.body));
        return new Response("{}", { status: 200 });
      }
      return new Response(JSON.stringify({ records: [] }), { status: 200 });
    });
    return slash_local_handle(
      env,
      "T_ORG",
      command,
      new URLSearchParams(params),
      "https://hooks.slack.com/r/x",
    ).then(() => posts);
  }

  it("refuses a gated command from a non-organiser workspace", async () => {
    const posts = await run("questions", {
      env: { SLACK_ORGANIZER_TEAM_ID: "T_OTHER", AIRTABLE_API_KEY: "k" },
      params: { user_name: "alice" },
    });
    expect(posts).toHaveLength(1);
    expect(posts[0].text).toMatch(/organisers workspace/i);
  });

  it("refuses a gated command for a non-member of the directory", async () => {
    const posts = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      if (typeof url === "string" && url.includes("hooks.slack.com")) {
        posts.push(JSON.parse(init.body));
        return new Response("{}", { status: 200 });
      }
      return new Response(
        JSON.stringify({ records: [{ fields: { organiser_slack: "someone" } }] }),
        { status: 200 },
      );
    });
    await slash_local_handle(
      { SLACK_ORGANIZER_TEAM_ID: "T_ORG", AIRTABLE_API_KEY: "k" },
      "T_ORG",
      "questions",
      new URLSearchParams({ user_name: "mallory" }),
      "https://hooks.slack.com/r/x",
    );
    expect(posts[0].text).toMatch(/global team/i);
  });

  it("does not gate open commands like remind-me", () => {
    expect(command_requires_global_team("remind-me in 5 | x")).toBe(false);
  });
});

describe("command_requires_organizer_workspace", () => {
  it("flags shorten", () => {
    expect(command_requires_organizer_workspace("shorten https://x.example")).toBe(true);
  });

  it("leaves the rest open", () => {
    expect(command_requires_organizer_workspace("pair @a @b")).toBe(false);
  });
});

describe("slash_local_handle organizer-workspace gate for shorten", () => {
  function run(command, { env, params }) {
    const posts = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      if (typeof url === "string" && url.includes("hooks.slack.com")) {
        posts.push(JSON.parse(init.body));
        return new Response("{}", { status: 200 });
      }
      return new Response(JSON.stringify({ records: [] }), { status: 200 });
    });
    return slash_local_handle(
      env,
      params.team_id || "T_ORG",
      command,
      new URLSearchParams(params),
      "https://hooks.slack.com/r/x",
    ).then(() => posts);
  }

  it("refuses shorten from a non-organiser workspace", async () => {
    const posts = await run("shorten https://guide.rladies.org/events/", {
      env: { SLACK_ORGANIZER_TEAM_ID: "T_ORG", SHORT_LINKS: makeKv() },
      params: { team_id: "T_COM", user_id: "U1" },
    });
    expect(posts).toHaveLength(1);
    expect(posts[0].text).toMatch(/organisers workspace/i);
  });

  it("shortens a link from the organiser workspace", async () => {
    const posts = await run("shorten https://guide.rladies.org/events/", {
      env: { SLACK_ORGANIZER_TEAM_ID: "T_ORG", SHORT_LINKS: makeKv() },
      params: { team_id: "T_ORG", user_id: "U1" },
    });
    expect(posts).toHaveLength(1);
    expect(posts[0].text).toMatch(/https:\/\/l\.rladies\.org\//);
  });

  it("returns usage text when no URL is given", async () => {
    const posts = await run("shorten", {
      env: { SLACK_ORGANIZER_TEAM_ID: "T_ORG", SHORT_LINKS: makeKv() },
      params: { team_id: "T_ORG", user_id: "U1" },
    });
    expect(posts[0].text).toMatch(/Usage/);
  });
});
