// Thin, generic passthrough to the `AI` Workers AI binding (wrangler.jsonc).
// Deliberately does no prompt- or schema-specific logic -- the caller (any
// RLadies+ repo with a JINX_WORKER_API_KEY) supplies the messages and an
// optional JSON schema; this route only resolves/validates the model and
// forwards the rest, so it stays reusable rather than encoding any one
// caller's domain logic.
//
// Workers AI has no alias or "latest" tag -- every call names an exact
// versioned id, and Cloudflare retires them (@cf/meta/llama-3.3-70b-instruct
// became ...-fp8-fast, breaking every caller that had pinned it). So `model`
// is optional: callers that don't care omit it and a rename is fixed here,
// once, for all of them. A caller that does care may still name one.
const DEFAULT_MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";
const ALLOWED_MODELS = new Set([DEFAULT_MODEL]);

export async function ai_generate_handle(request, env) {
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { messages, response_format, max_tokens } = payload;
  const model = payload.model ?? DEFAULT_MODEL;

  if (!ALLOWED_MODELS.has(model)) {
    return new Response(
      `Unsupported model ${model}. Allowed: ${[...ALLOWED_MODELS].join(", ")}`,
      { status: 400 },
    );
  }
  if (!Array.isArray(messages) || messages.length === 0) {
    return new Response("messages is required", { status: 400 });
  }

  try {
    const result = await env.AI.run(model, {
      messages,
      response_format,
      max_tokens,
    });
    return new Response(JSON.stringify({ result }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("AI run failed:", err);
    return new Response(`AI run failed: ${err.message}`, { status: 502 });
  }
}
