const MIN_CHARS = 60;

export async function gatherAwesomeCreationsSource(src) {
  const out = [];
  for (const feed of src.feeds) {
    const items = await fetchJson(feed.url);
    if (!items || !Array.isArray(items)) {
      console.error(`  awesome-creations: no array at ${feed.url}`);
      continue;
    }
    let kept = 0;
    for (const item of items) {
      const chunk = formatItem(item, feed, src);
      if (!chunk) continue;
      if (chunk.text.length < MIN_CHARS) continue;
      out.push(chunk);
      kept++;
    }
    console.log(`  ${kept}/${items.length} chunks from ${feed.kind}`);
  }
  console.log(`  ${out.length} chunks from awesome-creations`);
  return out;
}

function formatItem(item, feed, src) {
  if (feed.kind === "package") return formatPackage(item, src);
  return formatContent(item, src);
}

function formatPackage(pkg, src) {
  if (!pkg.name) return null;
  const url = pkg.pkdown_url || pkg.repo_url;
  if (!url) return null;
  const lines = [
    `Package: ${pkg.name}`,
    `Title: ${pkg.title || pkg.name}`,
  ];
  const authors = formatAuthors(pkg.authors);
  if (authors) lines.push(`Authors: ${authors}`);
  if (pkg.repo_url) lines.push(`Repository: ${pkg.repo_url}`);
  if (pkg.pkdown_url) lines.push(`Documentation: ${pkg.pkdown_url}`);
  if (pkg.last_updated) lines.push(`Last updated: ${pkg.last_updated}`);
  if (pkg.description) {
    lines.push("");
    lines.push(String(pkg.description).replace(/\s+/g, " ").trim());
  }
  const date = parseDate(pkg.last_updated);
  return {
    text: lines.join("\n"),
    heading: "R package",
    title: `${pkg.name} — ${pkg.title || "R package by an RLadies+ member"}`,
    repo: src.repo,
    path: `package/${pkg.name}`,
    url,
    date,
    lastmod: date,
    chunk_idx: 0,
  };
}

function formatContent(item, src) {
  if (!item.url) return null;
  const url = normalizeUrl(item.url);
  const lines = [
    `Title: ${item.title || url}`,
    `Type: ${item.type || "content"}`,
  ];
  if (item.language) lines.push(`Language: ${item.language}`);
  const authors = formatAuthors(item.authors);
  if (authors) lines.push(`Authors: ${authors}`);
  if (item.description) {
    lines.push("");
    lines.push(String(item.description).replace(/\s+/g, " ").trim());
  }
  return {
    text: lines.join("\n"),
    heading: item.type || "Community content",
    title: item.title || url,
    repo: src.repo,
    path: `content/${slugify(item.title || url)}`,
    url,
    date: 0,
    lastmod: 0,
    chunk_idx: 0,
  };
}

function formatAuthors(authors) {
  if (!Array.isArray(authors) || authors.length === 0) return "";
  return authors
    .map((a) => a && a.name)
    .filter(Boolean)
    .join(", ");
}

function normalizeUrl(raw) {
  const s = String(raw).trim();
  if (/^https?:\/\//i.test(s)) return s;
  return `https://${s}`;
}

function slugify(s) {
  return String(s)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function parseDate(raw) {
  if (!raw) return 0;
  const ms = Date.parse(raw);
  if (Number.isNaN(ms)) return 0;
  return Math.floor(ms / 1000);
}

async function fetchJson(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": "rladies-jinx-indexer" },
  });
  if (!res.ok) {
    console.error(`  awesome-creations fetch ${url} -> ${res.status}`);
    return null;
  }
  return res.json();
}
