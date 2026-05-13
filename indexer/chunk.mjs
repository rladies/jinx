const TARGET_CHARS = 1800;
const MIN_CHARS = 200;

export function chunkMarkdown(markdown, meta) {
  const { body, frontmatter } = stripFrontmatter(markdown);
  const sections = splitBySections(body);

  const out = [];
  for (const section of sections) {
    const pieces = splitToTarget(section.body, TARGET_CHARS);
    for (const piece of pieces) {
      const text = piece.trim();
      if (text.length < MIN_CHARS) continue;
      out.push({
        text,
        heading: section.heading,
        title: frontmatter.title || meta.fallbackTitle,
        repo: meta.repo,
        path: meta.path,
        url: meta.url,
      });
    }
  }
  return out;
}

export function stripFrontmatter(md) {
  const m = md.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!m) return { body: md, frontmatter: {} };
  return { body: m[2], frontmatter: parseFrontmatter(m[1]) };
}

function parseFrontmatter(text) {
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) continue;
    let v = m[2].trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    out[m[1]] = v;
  }
  return out;
}

function splitBySections(body) {
  const sections = [];
  let current = { heading: "", body: "" };
  for (const line of body.split(/\r?\n/)) {
    const h = line.match(/^(#{1,3})\s+(.*)$/);
    if (h && h[1].length <= 2) {
      if (current.body.trim()) sections.push(current);
      current = { heading: h[2].trim(), body: "" };
    } else {
      current.body += line + "\n";
    }
  }
  if (current.body.trim()) sections.push(current);
  return sections;
}

function splitToTarget(text, target) {
  if (text.length <= target) return [text];
  const paragraphs = text.split(/\n\s*\n/);
  const out = [];
  let buf = "";
  for (const p of paragraphs) {
    if (p.length > target) {
      if (buf) {
        out.push(buf);
        buf = "";
      }
      for (const piece of hardSplit(p, target)) out.push(piece);
      continue;
    }
    if (buf && (buf + "\n\n" + p).length > target) {
      out.push(buf);
      buf = p;
    } else {
      buf = buf ? buf + "\n\n" + p : p;
    }
  }
  if (buf) out.push(buf);
  return out;
}

function hardSplit(text, target) {
  const sentences = text.split(/(?<=[.!?])\s+/);
  const out = [];
  let buf = "";
  for (const s of sentences) {
    if (s.length > target) {
      if (buf) {
        out.push(buf);
        buf = "";
      }
      for (let i = 0; i < s.length; i += target) {
        out.push(s.slice(i, i + target));
      }
      continue;
    }
    if (buf && (buf + " " + s).length > target) {
      out.push(buf);
      buf = s;
    } else {
      buf = buf ? buf + " " + s : s;
    }
  }
  if (buf) out.push(buf);
  return out;
}
