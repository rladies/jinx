#!/usr/bin/env node
import { readFileSync } from "node:fs";
import {
  rag_build_messages,
  rag_repair_links,
  rag_source_urls,
  rerank_matches,
} from "../src/rag.js";

const DEFAULT_QUERIES = [
  "Tell me about RLadies+ and DataCamp.",
  "How do I start an RLadies+ chapter?",
  "Where can I find the RLadies+ code of conduct?",
  "How do I report a code of conduct violation?",
  "What does the /jinx help command do?",
  "How do I run an RLadies+ event?",
  "What is the Jinx privacy policy?",
];

const EMBED_MODEL = "@cf/baai/bge-base-en-v1.5";
const CHAT_MODEL = "@cf/meta/llama-3.1-8b-instruct";
const INDEX_NAME = process.env.VECTORIZE_INDEX || "rladies-content";
const RETRIEVE_K = 20;
const TOP_K = 5;
const MIN_SCORE = 0.4;

const CLOUDFLARE_API_TOKEN = required("CLOUDFLARE_API_TOKEN");
const CLOUDFLARE_ACCOUNT_ID =
  process.env.CLOUDFLARE_ACCOUNT_ID || (await discover_account_id(CLOUDFLARE_API_TOKEN));

const queriesFile = process.argv.slice(2).find((a) => !a.startsWith("-"));
const queries = queriesFile
  ? JSON.parse(readFileSync(queriesFile, "utf8"))
  : DEFAULT_QUERIES;

const SLACK_LINK_RE = /<(https?:\/\/[^|>]+)\|([^>]+)>/g;
const BARE_URL_RE = /(?<![<|])\bhttps?:\/\/[^\s)>]+/g;

const rows = [];
for (const q of queries) {
  process.stdout.write(`• ${truncate(q, 60)} ... `);
  try {
    const embedding = await embed(q);
    const matches = await vectorize_query(embedding);
    const filtered = matches.filter((m) => m.score >= MIN_SCORE);
    const ranked = rerank_matches(filtered, Date.now() / 1000).slice(0, TOP_K);

    if (ranked.length === 0) {
      rows.push({ query: q, status: "no-matches" });
      process.stdout.write("no matches\n");
      continue;
    }

    const messages = rag_build_messages(q, ranked);
    const raw_answer = await chat(messages);
    const allowed_urls = rag_source_urls(ranked);
    const answer = rag_repair_links(raw_answer, allowed_urls);
    const allowed = new Set(allowed_urls);

    const slack_links = [...answer.matchAll(SLACK_LINK_RE)];
    const bare_urls = [...answer.matchAll(BARE_URL_RE)];
    const linked_urls = slack_links.map((m) => m[1]);
    const invented = linked_urls.filter((u) => !allowed.has(u));

    rows.push({
      query: q,
      status: "ok",
      slack_link_count: slack_links.length,
      bare_url_count: bare_urls.length,
      invented_url_count: invented.length,
      answer_chars: answer.length,
      answer,
      ranked_urls: [...allowed],
      invented,
    });
    process.stdout.write(
      `${slack_links.length} links${invented.length ? ` (${invented.length} invented!)` : ""}, ${bare_urls.length} bare\n`
    );
  } catch (err) {
    rows.push({ query: q, status: "error", error: err.message });
    process.stdout.write(`FAIL — ${err.message}\n`);
  }
}

const ok = rows.filter((r) => r.status === "ok");
const linked = ok.filter((r) => r.slack_link_count > 0);
const invented = ok.filter((r) => r.invented_url_count > 0);
const bare = ok.filter((r) => r.bare_url_count > 0);

console.log("\n--- summary ---");
console.log(`answered:        ${ok.length}/${rows.length}`);
console.log(`with Slack link: ${linked.length}/${ok.length}`);
console.log(`with bare URL:   ${bare.length}/${ok.length}`);
console.log(`with invented:   ${invented.length}/${ok.length}`);

if (process.env.JINX_EVAL_VERBOSE === "1") {
  console.log("\n--- answers ---");
  for (const r of ok) {
    console.log(`\nQ: ${r.query}`);
    console.log(`A: ${r.answer}`);
    if (r.invented.length) console.log(`  invented URLs: ${r.invented.join(", ")}`);
  }
}

process.exit(0);

async function embed(text) {
  const json = await cf_post(`ai/run/${EMBED_MODEL}`, { text: [text] });
  return json.result.data[0];
}

async function chat(messages) {
  const json = await cf_post(`ai/run/${CHAT_MODEL}`, { messages, max_tokens: 400 });
  return (json.result?.response || "").trim();
}

async function vectorize_query(vector) {
  const json = await cf_post(
    `vectorize/v2/indexes/${INDEX_NAME}/query`,
    { vector, topK: RETRIEVE_K, returnMetadata: "all" }
  );
  return json.result?.matches || [];
}

async function cf_post(path, body) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/${path}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CLOUDFLARE_API_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );
  if (!res.ok) {
    throw new Error(`${path} failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function discover_account_id(token) {
  const res = await fetch("https://api.cloudflare.com/client/v4/accounts", {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`Failed to list accounts: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  const accounts = json.result || [];
  if (accounts.length === 0) throw new Error("Token has no accessible accounts.");
  if (accounts.length > 1) {
    throw new Error(
      `Token has access to ${accounts.length} accounts. Set CLOUDFLARE_ACCOUNT_ID.`
    );
  }
  return accounts[0].id;
}

function required(name) {
  const v = process.env[name];
  if (!v) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
  return v;
}

function truncate(s, n) {
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}
