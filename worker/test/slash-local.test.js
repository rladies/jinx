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

describe("slash_local_handle invite-link leadership gate", () => {
  function run(command, { userEmail, tokens } = {}) {
    const posts = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      if (url.includes("users.info")) {
        return new Response(
          JSON.stringify({ ok: true, user: { profile: { email: userEmail } } }),
          { status: 200 },
        );
      }
      if (url.includes("hooks.slack.com")) {
        posts.push(JSON.parse(init.body));
        return new Response("{}", { status: 200 });
      }
      return new Response("{}", { status: 200 });
    });
    const env = {
      INVITE_ADMIN_EMAIL: "leadership@rladies.org",
      INVITE_TOKENS: tokens || makeKv(),
      SLACK_TOKENS: makeKv({ "team:T_ORG": JSON.stringify({ bot_token: "xoxb" }) }),
    };
    return slash_local_handle(
      env,
      "T_ORG",
      command,
      new URLSearchParams({ user_id: "U1" }),
      "https://hooks.slack.com/r/x",
    ).then(() => ({ posts, env }));
  }

  const LINK = "https://join.slack.com/t/x/shared_invite/zt-1";

  it("refuses a caller who isn't the leadership account", async () => {
    const { posts, env } = await run(`invite-link ${LINK}`, {
      userEmail: "member@example.com",
    });
    expect(posts[0].text).toMatch(/Leadership/i);
    expect(await env.INVITE_TOKENS.get("config:master_invite_link")).toBe(null);
  });

  it("updates the link for the leadership account", async () => {
    const { posts, env } = await run(`invite-link ${LINK}`, {
      userEmail: "leadership@rladies.org",
    });
    expect(posts[0].text).toMatch(/updated/i);
    const m = await env.INVITE_TOKENS.get("config:master_invite_link", "json");
    expect(m.url).toContain("zt-1");
  });

  it("shows usage without leaking the url when called with no args", async () => {
    const tokens = makeKv({
      "config:master_invite_link": JSON.stringify({ url: LINK, cap: 400, used: 120 }),
    });
    const { posts } = await run("invite-link", {
      userEmail: "leadership@rladies.org",
      tokens,
    });
    expect(posts[0].text).toMatch(/120\/400/);
    expect(posts[0].text).not.toContain("zt-1");
  });

  it("says no link is set yet when the status is empty", async () => {
    const { posts } = await run("invite-link", {
      userEmail: "leadership@rladies.org",
    });
    expect(posts[0].text).toMatch(/No invite link is set yet/i);
  });

  it("reports the validation error for a non-Slack url and stores nothing", async () => {
    const { posts, env } = await run("invite-link https://evil.example/x", {
      userEmail: "leadership@rladies.org",
    });
    expect(posts[0].text).toMatch(/isn't a Slack invite link/i);
    expect(await env.INVITE_TOKENS.get("config:master_invite_link")).toBe(null);
  });
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
  it("only recognises shorten and invite-link as local commands", () => {
    expect(slash_is_local("shorten https://x.example")).toBe(true);
    expect(slash_is_local("invite-link https://join.example")).toBe(true);
    expect(slash_is_local("questions 30")).toBe(false);
    expect(slash_is_local("feedback")).toBe(false);
    expect(slash_is_local("setup-channel")).toBe(false);
    expect(slash_is_local("remind-me later | x")).toBe(false);
    expect(slash_is_local("pair @a @b")).toBe(false);
  });
});
