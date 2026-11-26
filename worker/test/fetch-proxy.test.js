import { describe, it, expect, vi, afterEach } from "vitest";
import { fetch_proxy_target, fetch_proxy_handle } from "../src/fetch-proxy.js";

afterEach(() => {
  vi.restoreAllMocks();
});

function post(body) {
  return new Request("https://jinx.rladies.workers.dev/content/fetch", {
    method: "POST",
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

describe("fetch_proxy_target", () => {
  it("accepts a public http(s) URL", () => {
    const target = fetch_proxy_target("https://drmowinckels.io/tags/r/index.xml");
    expect(target.error).toBeUndefined();
    expect(target.url.hostname).toBe("drmowinckels.io");
  });

  it("rejects a missing or non-string url", () => {
    expect(fetch_proxy_target(undefined).error).toMatch(/required/);
    expect(fetch_proxy_target("").error).toMatch(/required/);
    expect(fetch_proxy_target({}).error).toMatch(/required/);
  });

  it("rejects a non-http scheme", () => {
    expect(fetch_proxy_target("file:///etc/passwd").error).toMatch(/http or https/);
    expect(fetch_proxy_target("javascript:alert(1)").error).toMatch(/http or https/);
  });

  it("rejects IP literals, so metadata endpoints stay unreachable", () => {
    expect(fetch_proxy_target("http://169.254.169.254/latest/meta-data/").error).toMatch(
      /public hostname/,
    );
    expect(fetch_proxy_target("http://127.0.0.1:8787/").error).toMatch(/public hostname/);
    expect(fetch_proxy_target("http://[::1]/").error).toMatch(/public hostname/);
  });

  it("rejects loopback and internal names", () => {
    expect(fetch_proxy_target("http://localhost/").error).toMatch(/public hostname/);
    expect(fetch_proxy_target("http://metadata.internal/").error).toMatch(/public hostname/);
    expect(fetch_proxy_target("http://db.local/").error).toMatch(/public hostname/);
    expect(fetch_proxy_target("http://intranet/").error).toMatch(/public hostname/);
  });
});

describe("fetch_proxy_handle", () => {
  it("returns the upstream body", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("<rss></rss>", {
        status: 200,
        headers: { "content-type": "application/xml" },
      }),
    );
    const resp = await fetch_proxy_handle(post({ url: "https://example.com/index.xml" }), {});
    expect(resp.status).toBe(200);
    expect(await resp.text()).toBe("<rss></rss>");
  });

  it("sends the indexer User-Agent to the upstream host", async () => {
    const seen = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      seen.push({ url, ua: init.headers["User-Agent"] });
      return new Response("ok", { status: 200 });
    });
    await fetch_proxy_handle(
      post({ url: "https://example.com/index.xml", user_agent: "jinx/1.2.3" }),
      {},
    );
    expect(seen[0].url).toBe("https://example.com/index.xml");
    expect(seen[0].ua).toBe("jinx/1.2.3");
  });

  it("mirrors an upstream error status rather than reporting success", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("denied", { status: 403 }));
    const resp = await fetch_proxy_handle(post({ url: "https://example.com/index.xml" }), {});
    expect(resp.status).toBe(403);
  });

  it("rejects a blocked target before fetching anything", async () => {
    const spy = vi.spyOn(globalThis, "fetch");
    const resp = await fetch_proxy_handle(post({ url: "http://169.254.169.254/" }), {});
    expect(resp.status).toBe(400);
    expect(spy).not.toHaveBeenCalled();
  });

  it("rejects an unparseable body", async () => {
    const resp = await fetch_proxy_handle(post("not json"), {});
    expect(resp.status).toBe(400);
    expect(await resp.text()).toMatch(/invalid JSON/);
  });

  it("reports an upstream network failure as a 502", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("timed out"));
    const resp = await fetch_proxy_handle(post({ url: "https://example.com/index.xml" }), {});
    expect(resp.status).toBe(502);
    expect(await resp.text()).toMatch(/timed out/);
  });

  it("refuses a body over the size cap", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("x".repeat(10), {
        status: 200,
        headers: { "content-length": String(3 * 1024 * 1024) },
      }),
    );
    const resp = await fetch_proxy_handle(post({ url: "https://example.com/index.xml" }), {});
    expect(resp.status).toBe(502);
    expect(await resp.text()).toMatch(/too large/);
  });
});
