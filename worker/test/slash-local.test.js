import { describe, it, expect, vi, afterEach } from "vitest";
import {
  command_requires_organizer_workspace,
  slash_is_local,
  slash_local_handle,
} from "../src/slash-local.js";
import { makeKv } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("command_requires_organizer_workspace", () => {
  it("flags shorten", () => {
    expect(command_requires_organizer_workspace("shorten https://x.example")).toBe(true);
  });

  it("leaves other commands open", () => {
    expect(command_requires_organizer_workspace("help")).toBe(false);
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

describe("slash_is_local", () => {
  it("only recognises shorten as a local command", () => {
    expect(slash_is_local("shorten https://x.example")).toBe(true);
    expect(slash_is_local("questions 30")).toBe(false);
    expect(slash_is_local("feedback")).toBe(false);
    expect(slash_is_local("setup-channel")).toBe(false);
    expect(slash_is_local("remind-me later | x")).toBe(false);
    expect(slash_is_local("pair @a @b")).toBe(false);
  });
});
