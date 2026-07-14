// Thin, generic passthrough to the `AI` Workers AI binding (wrangler.jsonc).
// Deliberately does no prompt- or schema-specific logic -- the caller (any
// RLadies+ repo with a JINX_API_KEY) supplies the model, messages, and an
// optional JSON schema; this route only validates the model against an
// allowlist and forwards the rest, so it stays reusable rather than
// encoding any one caller's domain logic.
const ALLOWED_MODELS = new Set(["@cf/meta/llama-3.3-70b-instruct"]);

export async function ai_generate_handle(request, env) {
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { model, messages, response_format, max_tokens } = payload;

  if (!ALLOWED_MODELS.has(model)) {
    return new Response("Unsupported model", { status: 400 });
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
