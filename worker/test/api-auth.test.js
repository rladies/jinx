import { describe, it, expect } from "vitest";
import { bearer_token_extract, api_key_verify } from "../src/api-auth.js";

describe("bearer_token_extract", () => {
  it("extracts the token from a well-formed Authorization header", () => {
    const req = new Request("https://jinx.example.com/ai/generate", {
      headers: { authorization: "Bearer abc123" },
    });
    expect(bearer_token_extract(req)).toBe("abc123");
  });

  it("returns an empty string when the header is missing or malformed", () => {
    const noHeader = new Request("https://jinx.example.com/ai/generate");
    expect(bearer_token_extract(noHeader)).toBe("");

    const wrongScheme = new Request("https://jinx.example.com/ai/generate", {
      headers: { authorization: "Basic abc123" },
    });
    expect(bearer_token_extract(wrongScheme)).toBe("");
  });
});

describe("api_key_verify", () => {
  it("returns true only for the exact matching key", async () => {
    expect(await api_key_verify("secret-key", "secret-key")).toBe(true);
    expect(await api_key_verify("secret-key", "wrong-key")).toBe(false);
  });

  it("returns false when either side is missing or empty", async () => {
    expect(await api_key_verify("secret-key", "")).toBe(false);
    expect(await api_key_verify("", "secret-key")).toBe(false);
    expect(await api_key_verify(undefined, "secret-key")).toBe(false);
    expect(await api_key_verify("secret-key", undefined)).toBe(false);
  });

  it("returns false for keys of different lengths", async () => {
    expect(await api_key_verify("short", "a-much-longer-wrong-key")).toBe(false);
  });
});
