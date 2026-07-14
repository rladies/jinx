import { describe, it, expect, afterEach, vi } from "vitest";
import { analytics_rum_handle } from "../src/analytics-rum.js";
import { makeEnv, mockFetch, jsonResponse } from "./_helpers.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function rumRequest(body) {
  return new Request("https://jinx.example.com/analytics/rum", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function validPayload(overrides = {}) {
  return {
    account_id: "acc-1",
    site_tag: "site-1",
    since: "2025-01-01T00:00:00Z",
    until: "2025-02-01T00:00:00Z",
    ...overrides,
  };
}

describe("analytics_rum_handle", () => {
  it("returns 400 on invalid JSON", async () => {
    const res = await analytics_rum_handle(rumRequest("not json"), makeEnv());
    expect(res.status).toBe(400);
  });

  it("returns 400 when required fields are missing", async () => {
    const res = await analytics_rum_handle(
      rumRequest({ account_id: "acc-1" }),
      makeEnv()
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 for an invalid dimension, including the reserved 'count'", async () => {
    const injection = await analytics_rum_handle(
      rumRequest(validPayload({ dimension: "date){__typename}(x:\"" })),
      makeEnv()
    );
    expect(injection.status).toBe(400);

    const reserved = await analytics_rum_handle(
      rumRequest(validPayload({ dimension: "count" })),
      makeEnv()
    );
    expect(reserved.status).toBe(400);
  });

  it("queries Cloudflare's GraphQL API and returns the groups on a happy path", async () => {
    let capturedBody;
    mockFetch((url, init) => {
      expect(url).toBe("https://api.cloudflare.com/client/v4/graphql");
      expect(init.headers.Authorization).toBe("Bearer test-cf-api-token");
      capturedBody = JSON.parse(init.body);
      return jsonResponse({
        data: {
          viewer: {
            accounts: [
              {
                rumPageloadEventsAdaptiveGroups: [
                  { count: 42, dimensions: { date: "2025-01-05" } },
                ],
              },
            ],
          },
        },
      });
    });

    const res = await analytics_rum_handle(
      rumRequest(validPayload()),
      makeEnv()
    );

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.groups).toEqual([
      { count: 42, dimensions: { date: "2025-01-05" } },
    ]);
    expect(capturedBody.variables.accountTag).toBe("acc-1");
    expect(capturedBody.variables.siteTag).toBe("site-1");
    expect(capturedBody.query).toMatch(/orderBy:\[date_ASC\]/);
  });

  it("uses count_DESC ordering for a non-date dimension", async () => {
    let capturedBody;
    mockFetch((url, init) => {
      capturedBody = JSON.parse(init.body);
      return jsonResponse({
        data: { viewer: { accounts: [{ rumPageloadEventsAdaptiveGroups: [] }] } },
      });
    });

    await analytics_rum_handle(
      rumRequest(validPayload({ dimension: "requestPath" })),
      makeEnv()
    );

    expect(capturedBody.query).toMatch(/orderBy:\[count_DESC\]/);
    expect(capturedBody.query).toMatch(/dimensions\{requestPath\}/);
  });

  it("returns 502 when Cloudflare's GraphQL response contains errors", async () => {
    mockFetch(() => jsonResponse({ errors: [{ message: "bad query" }] }, 200));

    const res = await analytics_rum_handle(
      rumRequest(validPayload()),
      makeEnv()
    );

    expect(res.status).toBe(502);
    const body = await res.json();
    expect(body.error[0].message).toBe("bad query");
  });

  it("returns 502 when the Cloudflare request itself fails", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(async () => {
      throw new Error("network down");
    });

    const res = await analytics_rum_handle(
      rumRequest(validPayload()),
      makeEnv()
    );

    expect(res.status).toBe(502);
  });
});
