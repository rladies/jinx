import { readFile, readdir, stat } from "node:fs/promises";
import { join, relative } from "node:path";
import * as cheerio from "cheerio";
import TurndownService from "turndown";
import { chunkMarkdown } from "../chunk.mjs";

const REFRESH_RE = /<meta[^>]+http-equiv=["']?refresh["']?/i;

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
});
turndown.remove(["script", "style", "noscript", "nav", "footer", "aside", "form", "button"]);

export async function gatherHugoSiteSource(src) {
  console.log(`Scanning ${src.repo} at ${src.publicDir}`);
  const files = await walk_html(src.publicDir);
  console.log(`  ${files.length} html files`);

  const out = [];
  let aliasStubs = 0;
  let nonEnglish = 0;
  let tooShort = 0;
  let parseErrors = 0;

  for (const file of files) {
    const rel = relative(src.publicDir, file);
    if (!is_english(rel, src.languageRoots)) {
      nonEnglish++;
      continue;
    }

    let html;
    try {
      html = await readFile(file, "utf8");
    } catch (e) {
      console.warn(`  read failed ${file}: ${e.message}`);
      parseErrors++;
      continue;
    }

    if (REFRESH_RE.test(html)) {
      aliasStubs++;
      continue;
    }

    const page = extract_page(html, rel, src);
    if (!page) {
      parseErrors++;
      continue;
    }
    if (page.body.trim().length < 200) {
      tooShort++;
      continue;
    }

    const chunks = chunkMarkdown(page.markdown, {
      repo: src.repo,
      path: rel,
      url: page.url,
      fallbackTitle: page.title,
    });
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
  }

  console.log(
    `  ${out.length} chunks  (skipped ${aliasStubs} alias stubs, ${nonEnglish} non-English, ${tooShort} thin, ${parseErrors} parse errors)`
  );
  return out;
}

function extract_page(html, rel, src) {
  const $ = cheerio.load(html);

  const title = strip_suffix(($("title").first().text() || "").trim(), src.titleSuffix);
  const description = ($('meta[name="description"]').attr("content") || "").trim();
  const date = parse_date(
    $('meta[property="article:published_time"]').attr("content") ||
      $('meta[property="article:modified_time"]').attr("content") ||
      ""
  );

  const main = $("main").first();
  const article = main.length ? main : $("article").first();
  if (!article.length) return null;

  article.find("script, style, noscript, nav, footer, aside, form, button").remove();

  const body = article.html() || "";
  let markdown = turndown.turndown(body).trim();
  if (description) {
    markdown = `${description}\n\n${markdown}`;
  }
  if (title && !markdown.startsWith(`# ${title}`)) {
    markdown = `# ${title}\n\n${markdown}`;
  }

  return {
    url: url_from_rel(rel, src.baseUrl),
    title,
    description,
    date,
    body: body,
    markdown,
  };
}

async function walk_html(dir) {
  const out = [];
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch (e) {
    console.warn(`  walk failed at ${dir}: ${e.message}`);
    return out;
  }
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      out.push(...(await walk_html(full)));
    } else if (e.isFile() && e.name.endsWith(".html")) {
      out.push(full);
    }
  }
  return out;
}

function is_english(rel, languageRoots) {
  if (!languageRoots || languageRoots.length === 0) return true;
  const first = rel.split(/[\\/]+/)[0];
  if (languageRoots.english === first) return true;
  return !languageRoots.others.includes(first);
}

function url_from_rel(rel, baseUrl) {
  const normalised = rel.split(/[\\/]+/).join("/");
  const trimmed = normalised.replace(/(?:^|\/)index\.html$/, "/");
  return baseUrl.replace(/\/$/, "") + "/" + trimmed.replace(/^\//, "");
}

function strip_suffix(s, suffix) {
  if (!suffix) return s;
  return s.endsWith(suffix) ? s.slice(0, -suffix.length).trim() : s;
}

function parse_date(raw) {
  if (!raw) return 0;
  const ms = Date.parse(raw);
  if (Number.isNaN(ms)) return 0;
  return Math.floor(ms / 1000);
}

export async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}
