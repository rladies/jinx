import { describe, it, expect } from "vitest";
import {
  short_link_create,
  short_link_lookup,
  short_link_redirect_handle,
  links_shorten_handle,
  SHORT_LINK_HOST,
} from "../src/short-links.js";
import { makeEnv } from "./_helpers.js";

function shortenRequest(body) {
  return new Request("https://jinx.example.com/links/shorten", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

describe("short_link_create", () => {
  it("rejects an unparseable URL", async () => {
    await expect(short_link_create(makeEnv(), { url: "not a url" })).rejects.toMatchObject({
      status: 400,
    });
  });

  it("rejects a non-http(s) protocol", async () => {
    await expect(
      short_link_create(makeEnv(), { url: "javascript:alert(1)" }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it("creates a new short link with a random code under the l.rladies.org host", async () => {
    const env = makeEnv();
    const result = await short_link_create(env, { url: "https://guide.rladies.org/events/" });
    expect(result.created).toBe(true);
    expect(result.shortUrl).toBe(`https://${SHORT_LINK_HOST}/${result.code}`);
    expect(await short_link_lookup(env, result.code)).toBe("https://guide.rladies.org/events/");
  });

  it("dedupes a second request for the same destination to the same code", async () => {
    const env = makeEnv();
    const first = await short_link_create(env, { url: "https://guide.rladies.org/events/" });
    const second = await short_link_create(env, { url: "https://guide.rladies.org/events/" });

    expect(second.code).toBe(first.code);
    expect(second.created).toBe(false);
    const codeEntries = Object.keys(env.SHORT_LINKS._dump()).filter((k) => k.startsWith("code:"));
    expect(codeEntries).toHaveLength(1);
  });

  it("creates a link under a requested custom slug", async () => {
    const env = makeEnv();
    const result = await short_link_create(env, {
      url: "https://guide.rladies.org/coc/",
      slug: "coc",
    });
    expect(result.code).toBe("coc");
    expect(result.created).toBe(true);
  });

  it("rejects a custom slug format that fails validation", async () => {
    await expect(
      short_link_create(makeEnv(), { url: "https://guide.rladies.org/coc/", slug: "a" }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it("rejects a custom slug already taken by a different destination", async () => {
    const env = makeEnv();
    await short_link_create(env, { url: "https://guide.rladies.org/coc/", slug: "coc" });

    await expect(
      short_link_create(env, { url: "https://guide.rladies.org/events/", slug: "coc" }),
    ).rejects.toMatchObject({ status: 409 });
  });

  it("re-requesting the same slug for the same destination is a no-op", async () => {
    const env = makeEnv();
    const first = await short_link_create(env, {
      url: "https://guide.rladies.org/coc/",
      slug: "coc",
    });
    const second = await short_link_create(env, {
      url: "https://guide.rladies.org/coc/",
      slug: "coc",
    });
    expect(second.created).toBe(false);
    expect(second.code).toBe(first.code);
  });

  it("rejects a custom slug for a destination that already has a different canonical code", async () => {
    const env = makeEnv();
    const auto = await short_link_create(env, { url: "https://guide.rladies.org/events/" });

    await expect(
      short_link_create(env, { url: "https://guide.rladies.org/events/", slug: "events-2026" }),
    ).rejects.toMatchObject({ status: 409, message: expect.stringContaining(auto.code) });
  });
});

describe("short_link_lookup", () => {
  it("returns null for an unknown code", async () => {
    expect(await short_link_lookup(makeEnv(), "nope")).toBeNull();
  });
});

describe("short_link_redirect_handle", () => {
  it("returns a friendly 200 for an empty code (root path)", async () => {
    const res = await short_link_redirect_handle(makeEnv(), "");
    expect(res.status).toBe(200);
  });

  it("returns 404 for an unknown code", async () => {
    const res = await short_link_redirect_handle(makeEnv(), "nope");
    expect(res.status).toBe(404);
  });

  it("301-redirects to the stored URL for a known code", async () => {
    const env = makeEnv();
    const { code } = await short_link_create(env, { url: "https://guide.rladies.org/events/" });

    const res = await short_link_redirect_handle(env, code);
    expect(res.status).toBe(301);
    expect(res.headers.get("Location")).toBe("https://guide.rladies.org/events/");
  });

  it("returns 404 (not a KV error) for a pathologically long code", async () => {
    const res = await short_link_redirect_handle(makeEnv(), "a".repeat(600));
    expect(res.status).toBe(404);
  });
});

describe("links_shorten_handle", () => {
  it("returns 400 (not a 500) for a valid-JSON non-object body", async () => {
    const res = await links_shorten_handle(shortenRequest("null"), makeEnv());
    expect(res.status).toBe(400);
  });

  it("returns 400 when url is missing", async () => {
    const res = await links_shorten_handle(shortenRequest({}), makeEnv());
    expect(res.status).toBe(400);
  });
});
