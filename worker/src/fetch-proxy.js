// Fetches a public URL from Cloudflare's network instead of from a GitHub
// Actions runner. Several curated blogs sit behind Cloudflare with Bot Fight
// Mode on, which managed-challenges the Azure ranges Actions runs on: the
// blog feed saw a steady 403 from those hosts and silently announced nothing.
// Egress from a Worker is scored differently, so the same request succeeds.
//
// Bearer-gated like the rest of the HTTP API. It is still a fetch proxy, so
// the target is validated and the response is capped rather than streamed
// through unbounded.

const MAX_BYTES = 2 * 1024 * 1024;
const TIMEOUT_MS = 10_000;

// Hostnames that must never be reachable through the proxy: an IP literal
// (which is how cloud metadata endpoints are addressed), a name with no dot,
// and the loopback/internal suffixes.
const BLOCKED_HOST = /^(\d{1,3}(\.\d{1,3}){3}|\[|localhost)$|\.(local|internal|localhost)$/i;

export function fetch_proxy_target(raw) {
  if (typeof raw !== "string" || raw === "") {
    return { error: "url is required" };
  }
  let url;
  try {
    url = new URL(raw);
  } catch {
    return { error: "url is not a valid URL" };
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    return { error: "url must be http or https" };
  }
  if (BLOCKED_HOST.test(url.hostname) || !url.hostname.includes(".")) {
    return { error: "url host is not a public hostname" };
  }
  return { url };
}

export async function fetch_proxy_handle(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return text_response("invalid JSON body", 400);
  }

  const target = fetch_proxy_target(body?.url);
  if (target.error) {
    return text_response(target.error, 400);
  }

  let upstream;
  try {
    upstream = await fetch(target.url.toString(), {
      method: "GET",
      headers: {
        "User-Agent": body?.user_agent || "rladies-jinx-indexer (+https://github.com/rladies/jinx)",
        Accept: "*/*",
      },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (err) {
    console.warn(`fetch-proxy: ${target.url.hostname} failed: ${err?.message}`);
    return text_response(`upstream fetch failed: ${err?.message || "unknown"}`, 502);
  }

  const payload = await read_capped(upstream);
  if (payload.error) {
    return text_response(payload.error, 502);
  }

  // Mirror the upstream status so the caller's own error handling still sees
  // a 403 as a 403 rather than as a proxy success carrying an error page.
  return new Response(payload.text, {
    status: upstream.status,
    headers: {
      "Content-Type": upstream.headers.get("content-type") || "text/plain",
    },
  });
}

async function read_capped(response) {
  const declared = Number(response.headers.get("content-length") || 0);
  if (declared > MAX_BYTES) {
    return { error: `upstream body too large (${declared} bytes)` };
  }
  const buffer = await response.arrayBuffer();
  if (buffer.byteLength > MAX_BYTES) {
    return { error: `upstream body too large (${buffer.byteLength} bytes)` };
  }
  return { text: new TextDecoder().decode(buffer) };
}

function text_response(message, status) {
  return new Response(message, {
    status,
    headers: { "Content-Type": "text/plain" },
  });
}
