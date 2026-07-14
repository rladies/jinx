import { describe, it, expect, vi } from "vitest";
import { ai_generate_handle } from "../src/ai-api.js";
import { makeEnv } from "./_helpers.js";

function generateRequest(body) {
  return new Request("https://jinx.example.com/ai/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

describe("ai_generate_handle", () => {
  it("returns 400 on invalid JSON", async () => {
    const res = await ai_generate_handle(generateRequest("not json"), makeEnv());
    expect(res.status).toBe(400);
  });

  it("returns 400 for a model not on the allowlist", async () => {
    const res = await ai_generate_handle(
      generateRequest({
        model: "@cf/some/unapproved-model",
        messages: [{ role: "user", content: "hi" }],
      }),
      makeEnv()
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 when messages is missing or empty", async () => {
    const missing = await ai_generate_handle(
      generateRequest({ model: "@cf/meta/llama-3.3-70b-instruct" }),
      makeEnv()
    );
    expect(missing.status).toBe(400);

    const empty = await ai_generate_handle(
      generateRequest({ model: "@cf/meta/llama-3.3-70b-instruct", messages: [] }),
      makeEnv()
    );
    expect(empty.status).toBe(400);
  });

  it("calls the AI binding and returns its result on a happy path", async () => {
    const run = vi.fn(async (model, input) => {
      expect(model).toBe("@cf/meta/llama-3.3-70b-instruct");
      expect(input.messages).toEqual([{ role: "user", content: "hi" }]);
      expect(input.response_format).toEqual({ type: "json_schema", json_schema: { type: "object" } });
      return { response: '{"answer":"hello"}' };
    });
    const env = { ...makeEnv(), AI: { run } };

    const res = await ai_generate_handle(
      generateRequest({
        model: "@cf/meta/llama-3.3-70b-instruct",
        messages: [{ role: "user", content: "hi" }],
        response_format: { type: "json_schema", json_schema: { type: "object" } },
      }),
      env
    );

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.result.response).toBe('{"answer":"hello"}');
    expect(run).toHaveBeenCalledTimes(1);
  });

  it("returns 502 when the AI binding throws", async () => {
    const env = {
      ...makeEnv(),
      AI: {
        run: vi.fn(async () => {
          throw new Error("model unavailable");
        }),
      },
    };

    const res = await ai_generate_handle(
      generateRequest({
        model: "@cf/meta/llama-3.3-70b-instruct",
        messages: [{ role: "user", content: "hi" }],
      }),
      env
    );

    expect(res.status).toBe(502);
    expect(await res.text()).toMatch(/model unavailable/);
  });
});
