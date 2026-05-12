import { readdir, readFile } from "node:fs/promises";
import { join, relative } from "node:path";
import { chunkMarkdown } from "../chunk.mjs";

export async function gatherMarkdownSource(src) {
  const dir = join(src.root, src.contentDir);
  console.log(`Scanning ${src.repo} at ${dir}`);
  const files = await walkMarkdown(dir);
  console.log(`  ${files.length} markdown files`);

  const out = [];
  let skipped = 0;
  for (const file of files) {
    const rel = relative(dir, file);
    if (!isEnglish(rel)) {
      skipped++;
      continue;
    }
    const md = await readFile(file, "utf-8");
    const meta = {
      repo: src.repo,
      path: rel,
      url: toUrl(src.baseUrl, rel),
      fallbackTitle: titleFromPath(rel),
    };
    const chunks = chunkMarkdown(md, meta);
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
  }
  console.log(`  ${out.length} chunks (skipped ${skipped} non-English files)`);
  return out;
}

function isEnglish(relPath) {
  const m = relPath.match(/\.([a-z]{2})\.(md|qmd)$/);
  return !m || m[1] === "en";
}

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
  return slug.replace(/[-_]+/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}
