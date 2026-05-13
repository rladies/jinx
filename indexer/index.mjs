import { createHash } from "node:crypto";
import { gatherHugoSiteSource } from "./sources/hugo-site.mjs";
import { gatherGithubOrgSource } from "./sources/github.mjs";
import { gatherPkgdownLlmsSource } from "./sources/pkgdown.mjs";
import { gatherGithubFilesSource } from "./sources/github-files.mjs";
import { gatherGithubRemoteFilesSource } from "./sources/github-remote-files.mjs";

const JINX_REPO_ROOT = process.env.JINX_PATH || "..";

const SOURCES = [
  {
    type: "hugo-site",
    source_type: "guide",
    repo: "rladies/rladiesguide",
    sitemap: "https://guide.rladies.org/sitemap.xml",
    titleSuffix: " :: R-Ladies organizational guidance",
    languageRoots: { english: "en", others: ["es"] },
  },
  {
    type: "hugo-site",
    source_type: "site",
    repo: "rladies/rladies.github.io",
    sitemap: "https://rladies.org/sitemap.xml",
    titleSuffix: " - RLadies+ Global",
    languageRoots: { english: null, others: ["es", "fr", "pt"] },
  },
  {
    type: "github-org",
    source_type: "github-org",
    org: "rladies",
  },
  {
    type: "pkgdown-llms",
    source_type: "pkgdown",
    org: "rladies",
  },
  {
    type: "github-files",
    source_type: "jinx-docs",
    repo: "rladies/jinx",
    root: JINX_REPO_ROOT,
    files: [
      {
        path: "inst/commands/help.md",
        url: "https://github.com/rladies/jinx/blob/main/inst/commands/help.md",
        title: "Jinx slash command reference",
      },
      {
        path: "NEWS.md",
        url: "https://rladies.org/jinx/news/index.html",
        title: "Jinx release notes",
      },
      {
        path: "PRIVACY.md",
        url: "https://rladies.org/jinx/articles/privacy.html",
        title: "Jinx privacy policy",
      },
    ],
  },
  {
    type: "github-remote-files",
    source_type: "github-files",
    repo: "rladies/glamour",
    files: [
      {
        path: "README.md",
        url: "https://github.com/rladies/glamour#readme",
        title: "Glamour — Quarto extension for RLadies+",
      },
      {
        path: "CHANGELOG.md",
        url: "https://github.com/rladies/glamour/blob/main/CHANGELOG.md",
        title: "Glamour changelog",
      },
    ],
  },
];

const CLOUDFLARE_API_TOKEN = required("CLOUDFLARE_API_TOKEN");
const CLOUDFLARE_ACCOUNT_ID =
  process.env.CLOUDFLARE_ACCOUNT_ID ||
  (await discoverAccountId(CLOUDFLARE_API_TOKEN));
const INDEX_NAME = process.env.VECTORIZE_INDEX || "rladies-content";
const EMBED_MODEL = "@cf/baai/bge-base-en-v1.5";
const BATCH = 50;

const all = [];
for (const src of SOURCES) {
  const chunks = await gather(src);
  for (const c of chunks) all.push({ ...c, source_type: src.source_type });
}

console.log(`\nTotal chunks: ${all.length}`);
if (all.length === 0) {
  console.error("No chunks produced — aborting upsert.");
  process.exit(1);
}

const vectors = [];
for (let i = 0; i < all.length; i += BATCH) {
  const batch = all.slice(i, i + BATCH);
  const embeds = await embed(batch.map((c) => c.text));
  for (let j = 0; j < batch.length; j++) {
    const c = batch[j];
    vectors.push({
      id: makeId(c.repo, c.path, c.chunk_idx),
      values: embeds[j],
      metadata: {
        url: c.url,
        title: c.title,
        heading: c.heading,
        repo: c.repo,
        path: c.path,
        text: c.text,
        source_type: c.source_type,
        date: c.date || 0,
      },
    });
  }
  console.log(`Embedded ${Math.min(i + BATCH, all.length)}/${all.length}`);
}

const result = await upsert(vectors);
console.log(`Upserted ${vectors.length} vectors to ${INDEX_NAME}.`, result);

async function gather(src) {
  switch (src.type) {
    case "hugo-site":
      return gatherHugoSiteSource(src);
    case "github-org":
      return gatherGithubOrgSource(src);
    case "pkgdown-llms":
      return gatherPkgdownLlmsSource(src);
    case "github-files":
      return gatherGithubFilesSource(src);
    case "github-remote-files":
      return gatherGithubRemoteFilesSource(src);
    default:
      console.error(`Unknown source type: ${src.type}`);
      return [];
  }
}

function makeId(repo, path, idx) {
  return createHash("sha256")
    .update(`${repo}|${path}|${idx}`)
    .digest("hex")
    .slice(0, 32);
}

async function embed(texts) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/ai/run/${EMBED_MODEL}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ text: texts }),
    }
  );
  if (!res.ok) {
    throw new Error(`Embed failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  return json.result.data;
}

async function upsert(vectors) {
  const ndjson = vectors.map((v) => JSON.stringify(v)).join("\n");
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/vectorize/v2/indexes/${INDEX_NAME}/upsert`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
        "Content-Type": "application/x-ndjson",
      },
      body: ndjson,
    }
  );
  if (!res.ok) {
    throw new Error(`Upsert failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

function required(name) {
  const v = process.env[name];
  if (!v) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return v;
}

async function discoverAccountId(token) {
  const res = await fetch("https://api.cloudflare.com/client/v4/accounts", {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`Failed to list accounts: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  const accounts = json.result || [];
  if (accounts.length === 0) {
    throw new Error("Token has no accessible Cloudflare accounts.");
  }
  if (accounts.length > 1) {
    console.error(
      `Token has access to ${accounts.length} accounts. Set CLOUDFLARE_ACCOUNT_ID explicitly.`
    );
    process.exit(1);
  }
  return accounts[0].id;
}
