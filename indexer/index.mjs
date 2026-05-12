import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import { createHash } from "node:crypto";
import { chunkMarkdown } from "./chunk.mjs";

const SOURCES = [
  {
    repo: "rladies/rladiesguide",
    root: process.env.RLADIESGUIDE_PATH || "_sources/rladiesguide",
    contentDir: "content",
    baseUrl: "https://guide.rladies.org",
  },
  {
    repo: "rladies/rladies.github.io",
    root: process.env.RLADIES_SITE_PATH || "_sources/rladies.github.io",
    contentDir: "content",
    baseUrl: "https://rladies.org",
  },
];

const CLOUDFLARE_API_TOKEN = required("CLOUDFLARE_API_TOKEN");
const CLOUDFLARE_ACCOUNT_ID =
  process.env.CLOUDFLARE_ACCOUNT_ID || (await discoverAccountId(CLOUDFLARE_API_TOKEN));
const INDEX_NAME = process.env.VECTORIZE_INDEX || "rladies-content";
const EMBED_MODEL = "@cf/baai/bge-base-en-v1.5";
const BATCH = 50;

const all = [];
for (const src of SOURCES) {
  const dir = join(src.root, src.contentDir);
  console.log(`Scanning ${src.repo} at ${dir}`);
  const files = await walkMarkdown(dir);
  console.log(`  ${files.length} markdown files`);
  for (const file of files) {
    const rel = relative(dir, file);
    const md = await readFile(file, "utf-8");
    const meta = {
      repo: src.repo,
      path: rel,
      url: toUrl(src.baseUrl, rel),
      fallbackTitle: titleFromPath(rel),
    };
    const chunks = chunkMarkdown(md, meta);
    for (let i = 0; i < chunks.length; i++) {
      all.push({ ...chunks[i], chunk_idx: i });
    }
  }
}

console.log(`Total chunks: ${all.length}`);
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
      },
    });
  }
  console.log(`Embedded ${Math.min(i + BATCH, all.length)}/${all.length}`);
}

const result = await upsert(vectors);
console.log(`Upserted ${vectors.length} vectors to ${INDEX_NAME}.`, result);

async function walkMarkdown(dir) {
  const out = [];
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      out.push(...(await walkMarkdown(full)));
    } else if (
      e.isFile() &&
      (e.name.endsWith(".md") || e.name.endsWith(".qmd"))
    ) {
      out.push(full);
    }
  }
  return out;
}

function toUrl(base, relPath) {
  let p = relPath.replace(/\.([a-z]{2})\.(md|qmd)$/, "");
  p = p.replace(/\.(md|qmd)$/, "");
  p = p.replace(/(^|\/)_index$/, "$1");
  p = p.replace(/(^|\/)index$/, "$1");
  if (p && !p.endsWith("/")) p += "/";
  return base.replace(/\/$/, "") + "/" + p.replace(/^\//, "");
}

function titleFromPath(relPath) {
  const stem = relPath.replace(/\.(md|qmd)$/, "").replace(/.*\//, "");
  if (!stem || stem === "_index" || stem === "index") {
    const parent = relPath.split("/").slice(-2, -1)[0] || "Home";
    return humanize(parent);
  }
  return humanize(stem);
}

function humanize(slug) {
  return slug
    .replace(/[-_]+/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
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
