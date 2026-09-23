import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  mailbox_local_part,
  workspace_token,
  mailbox_create,
  workspace_mailbox_handle,
} from "../src/workspace.js";
import { makeEnv } from "./_helpers.js";

// A throwaway RSA key so the JWT signing path runs for real rather than
// being mocked away - it is the part most likely to break silently.
async function testKeyPem() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  const b64 = Buffer.from(pkcs8).toString("base64");
  return `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----`;
}

async function workspaceEnv(overrides = {}) {
  return makeEnv({
    WORKSPACE_SA_EMAIL: "sa@project.iam.gserviceaccount.com",
    WORKSPACE_SUBJECT: "jinx-provisioner@rladies.org",
    WORKSPACE_SA_PRIVATE_KEY: await testKeyPem(),
    WORKSPACE_DOMAIN: "rladies.org",
    WORKSPACE_OU: "/Chapters",
    ...overrides,
  });
}

function mailboxRequest(body, method = "POST") {
  return new Request("https://jinx.example.com/workspace/mailbox", {
    method,
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

describe("mailbox_local_part", () => {
  it("transliterates accented city names", () => {
    expect(mailbox_local_part("Córdoba")).toBe("cordoba");
    expect(mailbox_local_part("São Paulo")).toBe("sao-paulo");
    expect(mailbox_local_part("Ōsaka")).toBe("osaka");
  });

  it("normalises punctuation and spacing", () => {
    expect(mailbox_local_part("St. John's")).toBe("st-john-s");
    expect(mailbox_local_part("-oslo")).toBe("oslo");
  });

  it("refuses reserved addresses however they are spelled", () => {
    for (const name of ["admin", "ADMIN", "Admin!", " jinx ", "info", "postmaster"]) {
      expect(() => mailbox_local_part(name)).toThrow(/reserved/);
    }
  });

  it("refuses names that are too short or too long", () => {
    expect(() => mailbox_local_part("a")).toThrow(/not a usable/i);
    expect(() => mailbox_local_part("a".repeat(40))).toThrow(/not a usable/i);
  });

  it("refuses empty and missing input", () => {
    expect(() => mailbox_local_part("")).toThrow();
    expect(() => mailbox_local_part(undefined)).toThrow();
    expect(() => mailbox_local_part("!!!")).toThrow();
  });
});

describe("workspace_token", () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("signs a JWT naming the impersonated subject and returns the token", async () => {
    globalThis.fetch.mockResolvedValue(
      new Response(JSON.stringify({ access_token: "at" }), { status: 200 }),
    );
    const token = await workspace_token(await workspaceEnv());
    expect(token).toBe("at");

    const body = globalThis.fetch.mock.calls[0][1].body;
    const assertion = new URLSearchParams(body).get("assertion");
    const claims = JSON.parse(Buffer.from(assertion.split(".")[1], "base64url").toString());
    expect(claims.sub).toBe("jinx-provisioner@rladies.org");
    expect(claims.scope).toBe("https://www.googleapis.com/auth/admin.directory.user");
  });

  it("refuses to run when impersonation is not configured", async () => {
    const env = await workspaceEnv({ WORKSPACE_SUBJECT: "" });
    await expect(workspace_token(env)).rejects.toThrow(/not configured/);
  });

  it("refuses to run without a key", async () => {
    const env = await workspaceEnv({ WORKSPACE_SA_PRIVATE_KEY: "" });
    await expect(workspace_token(env)).rejects.toThrow(/not configured/);
  });

  it("fails loudly when the exchange returns no token", async () => {
    globalThis.fetch.mockResolvedValue(
      new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 }),
    );
    await expect(workspace_token(await workspaceEnv())).rejects.toThrow(/token exchange failed/);
  });
});

describe("mailbox_create", () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  function mockCreation(status, body = {}) {
    globalThis.fetch
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: "at" }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify(body), { status }));
  }

  it("creates the mailbox in the chapters OU", async () => {
    mockCreation(200, { primaryEmail: "oslo@rladies.org" });
    const result = await mailbox_create(await workspaceEnv(), { city: "Oslo" });
    expect(result.email).toBe("oslo@rladies.org");

    const sent = JSON.parse(globalThis.fetch.mock.calls[1][1].body);
    expect(sent.orgUnitPath).toBe("/Chapters");
    expect(sent.changePasswordAtNextLogin).toBe(true);
  });

  it("never returns the generated password to the caller", async () => {
    mockCreation(200, { primaryEmail: "oslo@rladies.org" });
    const result = await mailbox_create(await workspaceEnv(), { city: "Oslo" });
    expect(JSON.stringify(result)).not.toMatch(/password/i);
    expect(Object.keys(result)).toEqual(["email", "orgUnitPath"]);
  });

  it("generates a different password every time", async () => {
    mockCreation(200);
    await mailbox_create(await workspaceEnv(), { city: "Oslo" });
    mockCreation(200);
    await mailbox_create(await workspaceEnv(), { city: "Bergen" });
    const first = JSON.parse(globalThis.fetch.mock.calls[1][1].body).password;
    const second = JSON.parse(globalThis.fetch.mock.calls[3][1].body).password;
    expect(first).not.toBe(second);
    expect(first.length).toBeGreaterThanOrEqual(64);
  });

  it("reports an existing mailbox as a conflict", async () => {
    mockCreation(409);
    await expect(mailbox_create(await workspaceEnv(), { city: "Oslo" })).rejects.toMatchObject({
      status: 409,
    });
  });

  it("does not echo the Directory API's own error text back", async () => {
    mockCreation(400, { error: { message: "Invalid Input: secret-looking detail" } });
    await expect(
      mailbox_create(await workspaceEnv(), { city: "Oslo" }),
    ).rejects.toThrow(/Workspace rejected the mailbox creation/);
  });

  it("validates the name before spending a token exchange", async () => {
    await expect(mailbox_create(await workspaceEnv(), { city: "admin" })).rejects.toThrow(/reserved/);
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });
});

describe("workspace_mailbox_handle", () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("rejects a non-POST request", async () => {
    const res = await workspace_mailbox_handle(mailboxRequest(undefined, "GET"), await workspaceEnv());
    expect(res.status).toBe(405);
  });

  it("requires a city", async () => {
    const res = await workspace_mailbox_handle(mailboxRequest({}), await workspaceEnv());
    expect(res.status).toBe(400);
  });

  it("survives a malformed body", async () => {
    const request = new Request("https://jinx.example.com/workspace/mailbox", {
      method: "POST",
      body: "not json",
    });
    const res = await workspace_mailbox_handle(request, await workspaceEnv());
    expect(res.status).toBe(400);
  });

  it("returns 201 and the address on success", async () => {
    globalThis.fetch
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: "at" }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({}), { status: 200 }));
    const res = await workspace_mailbox_handle(mailboxRequest({ city: "Oslo" }), await workspaceEnv());
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({ email: "oslo@rladies.org" });
  });

  it("passes a reserved name back as a 400, not a 500", async () => {
    const res = await workspace_mailbox_handle(mailboxRequest({ city: "admin" }), await workspaceEnv());
    expect(res.status).toBe(400);
  });
});
