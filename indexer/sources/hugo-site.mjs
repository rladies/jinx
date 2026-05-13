import * as cheerio from "cheerio";
import TurndownService from "turndown";
import { chunkMarkdown } from "../chunk.mjs";

const USER_AGENT = "rladies-jinx-indexer/0.1 (+https://github.com/rladies/jinx)";
const FETCH_CONCURRENCY = 8;
const FETCH_RETRIES = 1;
const FETCH_RETRY_DELAY_MS = 2000;

// Hardcoded URL paths to skip — these pages have public sitemap entries but
// their content is either noise for retrieval (individual member profiles)
// or duplicated elsewhere in the index.
const SKIP_PATH_PATTERNS = [
  /^\/directory\/[^/]+\/?$/,
];

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
});
turndown.remove(["script", "style", "noscript", "nav", "footer", "aside", "form", "button"]);

export async function gatherHugoSiteSource(src) {
  console.log(`Crawling ${src.repo} via ${src.sitemap}`);
  const urls = await collect_sitemap_urls(src.sitemap);
  console.log(`  ${urls.length} URLs from sitemap`);

  const filtered = urls.filter((u) => is_english(u, src) && !is_skipped(u));
  console.log(`  ${filtered.length} to crawl after filters`);

  const out = [];
  let fetchFailed = 0;
  let noArticle = 0;
  let tooShort = 0;
  let withDescription = 0;

  await pool(filtered, FETCH_CONCURRENCY, async (url) => {
    const html = await fetch_html(url);
    if (!html) {
      fetchFailed++;
      return;
    }

    const page = extract_page(html, normalize_url(url), src);
    if (!page) {
      noArticle++;
      return;
    }
    if (page.markdown.length < 200) {
      tooShort++;
      return;
    }
    if (page.description) withDescription++;

    const chunks = chunkMarkdown(page.markdown, {
      repo: src.repo,
      path: url_path(page.url),
      url: page.url,
      fallbackTitle: page.title,
    });
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
  });

  console.log(
    `  ${out.length} chunks  (fetch-fail ${fetchFailed}, no <main>/<article> ${noArticle}, thin ${tooShort}, w/ description ${withDescription})`
  );
  return out;
}

async function collect_sitemap_urls(url, depth = 0) {
  if (depth > 2) return [];
  const xml = await fetch_text(url);
  if (!xml) return [];
  const isIndex = /<sitemapindex\b/.test(xml);
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim());
  if (!isIndex) return locs;
  const out = [];
  for (const child of locs) {
    out.push(...(await collect_sitemap_urls(child, depth + 1)));
  }
  return out;
}

function extract_page(html, url, src) {
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
  if (description) markdown = `${description}\n\n${markdown}`;
  if (title && !markdown.startsWith(`# ${title}`)) markdown = `# ${title}\n\n${markdown}`;

  return { url, title, description, date, markdown };
}

function is_english(url, src) {
  const u = new URL(url);
  const first = u.pathname.split("/").filter(Boolean)[0];
  if (!first) return true;
  if (src.languageRoots?.english === first) return true;
  return !src.languageRoots?.others?.includes(first);
}

function is_skipped(url) {
  const path = new URL(url).pathname;
  return SKIP_PATH_PATTERNS.some((re) => re.test(path));
}

function normalize_url(url) {
  return url.replace(/\/index\.html$/, "/");
}

function url_path(url) {
  return new URL(url).pathname;
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

async function fetch_html(url) {
  return fetch_with_retry(url);
}

async function fetch_text(url) {
  return fetch_with_retry(url);
}

async function fetch_with_retry(url) {
  let lastErr;
  for (let attempt = 0; attempt <= FETCH_RETRIES; attempt++) {
    try {
      const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
      if (!res.ok) {
        lastErr = new Error(`HTTP ${res.status}`);
        if (res.status >= 400 && res.status < 500) break;
      } else {
        return await res.text();
      }
    } catch (err) {
      lastErr = err;
    }
    if (attempt < FETCH_RETRIES) await sleep(FETCH_RETRY_DELAY_MS);
  }
  console.warn(`  fetch failed ${url}: ${lastErr?.message || "unknown"}`);
  return null;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function pool(items, limit, worker) {
  const queue = items.slice();
  const total = items.length;
  let started = 0;
  const runners = Array.from({ length: Math.min(limit, queue.length) }, async () => {
    while (queue.length) {
      const item = queue.shift();
      started++;
      if (started % 200 === 0) process.stdout.write(`  …${started}/${total}\n`);
      await worker(item);
    }
  });
  await Promise.all(runners);
}
