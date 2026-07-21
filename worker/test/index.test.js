import { describe, it, expect, afterEach, vi } from "vitest";
import worker from "../src/index.js";
import { makeEnv, makeCtx, signSlack } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function makeRequest(url, init = {}) {
  return new Request(url, init);
}

describe("worker fetch routing", () => {
  it("answers GET / with a friendly status string", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/"),
      env,
      makeCtx()
    );
    expect(res.status).toBe(200);
    expect(await res.text()).toMatch(/Jinx/);
  });

  it("routes GET /slack/install to a 302 to slack.com with expected scopes", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/slack/install"),
      env,
      makeCtx()
    );
    expect(res.status).toBe(302);
    const location = res.headers.get("Location");
    expect(location).toMatch(/^https:\/\/slack\.com\/oauth\/v2\/authorize/);
    const authUrl = new URL(location);
    expect(authUrl.searchParams.get("client_id")).toBe("test-client-id");
    const scope = authUrl.searchParams.get("scope") || "";
    for (const expected of [
      "commands",
      "chat:write",
      "app_mentions:read",
      "assistant:write",
      "im:history",
      "users:read.email",
    ]) {
      expect(scope.split(",")).toContain(expected);
    }
    expect(res.headers.get("Set-Cookie")).toMatch(/jinx_install_nonce=/);
  });

  it("returns 404 for unknown POST paths", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/nope", { method: "POST" }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(404);
  });

  it("rejects Slack POSTs without a valid signature", async () => {
    const env = makeEnv();
    const body = "token=xxx&team_id=T_ORG&text=help";
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/slack/command", {
        method: "POST",
        headers: {
          "x-slack-request-timestamp": String(Math.floor(Date.now() / 1000)),
          "x-slack-signature": "v0=deadbeef",
        },
        body,
      }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(401);
  });

  it("accepts Slack POSTs with a valid signature and routes to the command handler", async () => {
    const env = makeEnv();
    const ts = String(Math.floor(Date.now() / 1000));
    const body = new URLSearchParams({
      team_id: "T_ORG",
      text: "help",
      user_id: "U1",
      user_name: "alice",
      channel_id: "C1",
      channel_name: "general",
      response_url: "https://hooks.slack.com/r/test",
    }).toString();
    const sig = await signSlack("test-signing-secret", ts, body);

    vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = typeof input === "string" ? input : input.url;
      if (url.startsWith("https://raw.githubusercontent.com/")) {
        return new Response("# Help text", { status: 200 });
      }
      return new Response("ok", { status: 200 });
    });

    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/slack/command", {
        method: "POST",
        headers: {
          "x-slack-request-timestamp": ts,
          "x-slack-signature": sig,
        },
        body,
      }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.response_type).toBe("ephemeral");
  });

  it("rejects /ai/generate and /links/shorten without a valid bearer key", async () => {
    const env = makeEnv();
    for (const path of ["/ai/generate", "/links/shorten"]) {
      const noAuth = await worker.fetch(
        makeRequest(`https://jinx.example.com${path}`, {
          method: "POST",
          body: "{}",
        }),
        env,
        makeCtx()
      );
      expect(noAuth.status).toBe(401);

      const badAuth = await worker.fetch(
        makeRequest(`https://jinx.example.com${path}`, {
          method: "POST",
          headers: { authorization: "Bearer wrong-key" },
          body: "{}",
        }),
        env,
        makeCtx()
      );
      expect(badAuth.status).toBe(401);
    }
  });

  it("routes an authenticated /ai/generate request to the AI binding", async () => {
    const env = {
      ...makeEnv(),
      AI: { run: vi.fn(async () => ({ response: "hi there" })) },
    };
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/ai/generate", {
        method: "POST",
        headers: { authorization: "Bearer test-jinx-api-key" },
        body: JSON.stringify({
          model: "@cf/meta/llama-3.3-70b-instruct",
          messages: [{ role: "user", content: "hi" }],
        }),
      }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.result.response).toBe("hi there");
  });

  it("routes an authenticated /links/shorten request to create a short link", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/links/shorten", {
        method: "POST",
        headers: { authorization: "Bearer test-jinx-api-key" },
        body: JSON.stringify({ url: "https://guide.rladies.org/events/" }),
      }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.short_url).toMatch(/^https:\/\/l\.rladies\.org\//);
  });

  it("redirects GET requests on the l.rladies.org host to the stored URL", async () => {
    const env = makeEnv();
    await env.SHORT_LINKS.put(
      "code:abc1234",
      JSON.stringify({ url: "https://guide.rladies.org/events/" })
    );

    const res = await worker.fetch(
      makeRequest("https://l.rladies.org/abc1234"),
      env,
      makeCtx()
    );
    expect(res.status).toBe(301);
    expect(res.headers.get("Location")).toBe("https://guide.rladies.org/events/");
  });

  it("returns 404 for an unknown code on the l.rladies.org host", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://l.rladies.org/nope"),
      env,
      makeCtx()
    );
    expect(res.status).toBe(404);
  });

  it("does not require a Slack signature on the Airtable webhook", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/airtable/webhook", {
        method: "POST",
        headers: { "x-airtable-secret": "test-airtable-secret" },
        body: JSON.stringify({}),
      }),
      env,
      makeCtx()
    );
    expect([400, 403, 500]).toContain(res.status);
  });

  it("returns a 503 with the error message when a handler throws (e.g. misconfigured allowlist)", async () => {
    const env = makeEnv({
      SLACK_ORGANIZER_TEAM_ID: undefined,
      SLACK_COMMUNITY_TEAM_ID: undefined,
    });
    const ts = String(Math.floor(Date.now() / 1000));
    const body = new URLSearchParams({
      team_id: "T_ORG",
      text: "help",
    }).toString();
    const sig = await signSlack("test-signing-secret", ts, body);

    const res = await worker.fetch(
      makeRequest("https://jinx.example.com/slack/command", {
        method: "POST",
        headers: {
          "x-slack-request-timestamp": ts,
          "x-slack-signature": sig,
        },
        body,
      }),
      env,
      makeCtx()
    );
    expect(res.status).toBe(503);
    const text = await res.text();
    expect(text).toMatch(/SLACK_ORGANIZER_TEAM_ID/);
  });
});
