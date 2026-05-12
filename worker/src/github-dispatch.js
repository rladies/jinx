export async function dispatchToGitHub(env, payload) {
  const token = await mintInstallationToken(env);

  const response = await fetch(
    `https://api.github.com/repos/${env.GITHUB_REPO}/dispatches`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: JSON.stringify({
        event_type: "slack-command",
        client_payload: payload,
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    console.error(`GitHub dispatch failed (${response.status}): ${text}`);
    throw new Error(`GitHub dispatch failed (${response.status})`);
  }
}

async function mintInstallationToken(env) {
  const jwt = await createJWT(env.JINX_APP_ID, env.JINX_PRIVATE_KEY);

  const installRes = await fetch(`https://api.github.com/app/installations`, {
    headers: {
      Authorization: `Bearer ${jwt}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "rladies-jinx",
    },
  });

  if (!installRes.ok) {
    throw new Error(`Failed to list installations: ${installRes.status}`);
  }

  const installations = await installRes.json();
  const installation = installations.find(
    (i) => i.account?.login?.toLowerCase() === "rladies"
  );

  if (!installation) {
    throw new Error("No installation found for rladies org");
  }

  const tokenRes = await fetch(
    `https://api.github.com/app/installations/${installation.id}/access_tokens`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${jwt}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
      },
    }
  );

  if (!tokenRes.ok) {
    throw new Error(`Failed to create installation token: ${tokenRes.status}`);
  }

  const { token } = await tokenRes.json();
  return token;
}

async function createJWT(appId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iat: now - 60,
    exp: now + 600,
    iss: appId,
  };

  const enc = new TextEncoder();
  const b64url = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64 = b64url(header);
  const payloadB64 = b64url(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await importPrivateKey(privateKeyPem);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    enc.encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

async function importPrivateKey(pem) {
  const pemContents = pem
    .replace(/-----BEGIN RSA PRIVATE KEY-----/, "")
    .replace(/-----END RSA PRIVATE KEY-----/, "")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}
