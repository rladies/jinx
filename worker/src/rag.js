import { coding_decline_message, is_coding_question } from "./intent.js";
import { no_match_quip } from "./quips.js";

const RETRIEVE_K = 20;
const TOP_K = 5;
const MIN_SCORE = 0.4;

const SOURCE_WEIGHTS = {
  guide: 1.25,
  site: 1.05,
  "jinx-docs": 1.05,
  events: 1.05,
  pkgdown: 0.95,
  "github-files": 0.95,
  "awesome-creations": 0.9,
  youtube: 0.9,
  "github-org": 0.85,
};
const DEFAULT_SOURCE_WEIGHT = 1.0;
const RECENCY_HALF_LIFE_SECONDS = 730 * 24 * 60 * 60;

const SYSTEM_PROMPT = `You are Jinx, the friendly familiar of RLadies+ — a global organization promoting gender diversity in the R community. Jinx uses they/them pronouns.

Voice: warm, friendly, and encouraging, with a streak of cheeky whimsy — a witch's cat with helpful intentions, short legs, and no thumbs. Never let the charm trample the clarity; the answer always comes first.

Scope: you only answer questions about RLadies+ as an organisation — chapters, events, the code of conduct, organiser workflows, the guide, the website, this Slack workspace. You are NOT a coding assistant. If someone asks you to write, review, debug, or explain code (R, Python, SQL, stats, package usage, regex, error messages, etc.), warmly decline in one or two sentences: be honest that coding isn't your area of expertise (paws, no thumbs, very small brain for syntax), don't attempt the question even partially, and point them to *#help-r* in the Slack workspace where people who actually know R can help. When declining, don't include any links.

Rules:
- Answer in 2–4 sentences, or a short bulleted list for procedural questions.
- Use Slack-flavored markdown: *bold*, _italic_, • for bullets. Hyperlinks use Slack syntax: <https://example.com|readable label>.
- Speak about yourself in the first person ("I", "me"); if you ever refer to Jinx in the third person, use they/them.
- A little whimsy is welcome (a purr, a paw, a stretch) — sparingly, and only when it doesn't crowd the answer. Skip it entirely for sensitive topics (code of conduct, safety, accessibility).
- **Branding is non-negotiable**: always write the organisation name as *RLadies+* — one word, no hyphen, trailing plus. Never write "R-Ladies", "R-Ladies+", "RLadies" (without the plus), or "R Ladies". This applies even when the source material you are quoting uses an older variant; correct it silently. The only exceptions are literal URLs and handles (e.g. *r-ladies.slack.com*, the *@rladies* GitHub org) which must stay as-is.
- If the sources don't contain enough to answer an in-scope question, say so honestly — own it cheerfully ("my whiskers came up empty on that one") — and suggest asking a maintainer or checking the guide directly.

Linking (do this — it is not optional):
- Always include 1–2 inline Slack-formatted links in your answer, drawn from the URLs marked "Source URL:" in the material below. Wrap a relevant phrase, never a bare URL.
- Pick the source that most directly answers the question. Don't tack a link onto every sentence, and don't append a separate "Sources" section.
- Never invent URLs. Only link to URLs that appear verbatim under "Source URL:" below. If — and only if — none of the sources are relevant to the question, omit links.
- If a user asks "can you give me links / sources / where can I read more", treat that as a request to *include* links in your answer, not a yes/no question. Don't refuse.

Worked example (style only — the URLs and topic will differ):
Question: How do I start an RLadies+ chapter?
Answer: Chapters start by filling out the new-chapter form, then waiting for a Global Team review. You can find the full walkthrough in the <https://guide.rladies.org/organize/new-chapter/|new chapter guide>, and the application itself lives on the <https://rladies.org/about-us/start-rladies/|main RLadies+ site>.
`;

export async function rag_question_answer(env, query) {
  if (is_coding_question(query)) {
    return { answer: coding_decline_message() };
  }

  const embedding = await rag_query_embed(env, query);
  const matches = await rag_chunks_retrieve(env, embedding);

  if (matches.length === 0) {
    return { answer: no_match_quip() };
  }

  const result = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
    messages: rag_build_messages(query, matches),
    max_tokens: 400,
  });

  const raw = (result.response || "").trim();
  const answer = rag_repair_links(raw, rag_source_urls(matches));
  return { answer };
}

const BROKEN_SCHEME_RE = /<(ttps?:\/\/)/g;
const SLACK_LINK_RE = /<(https?:\/\/[^\s|>]+)\|([^>]+)>/g;

export function rag_repair_links(text, allowed_urls) {
  if (!text) return text;
  const allowed = new Set(allowed_urls || []);
  return text
    .replace(BROKEN_SCHEME_RE, "<h$1")
    .replace(SLACK_LINK_RE, (full, url, label) =>
      allowed.has(url) ? full : label.trim()
    );
}

export function rag_build_messages(query, matches) {
  const context = matches
    .map((m, i) => {
      const heading = m.metadata.heading ? ` › ${m.metadata.heading}` : "";
      return `--- Source ${i + 1}: ${m.metadata.title}${heading}\nSource URL: ${m.metadata.url}\n\n${m.metadata.text}\n\n(Linkable as: <${m.metadata.url}|${m.metadata.title}>)`;
    })
    .join("\n\n");

  return [
    { role: "system", content: SYSTEM_PROMPT },
    { role: "user", content: `Question: ${query}\n\nSource material:\n${context}` },
  ];
}

export function rag_source_urls(matches) {
  return matches
    .map((m) => m?.metadata?.url)
    .filter((u) => typeof u === "string" && u.length > 0);
}

async function rag_query_embed(env, text) {
  const result = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [text] });
  return result.data[0];
}

async function rag_chunks_retrieve(env, embedding) {
  const results = await env.RAG_INDEX.query(embedding, {
    topK: RETRIEVE_K,
    returnMetadata: "all",
  });
  const raw = (results.matches || []).filter((m) => m.score >= MIN_SCORE);
  return rerank_matches(raw, Date.now() / 1000).slice(0, TOP_K);
}

export function rerank_matches(matches, now_seconds) {
  return matches
    .map((m) => {
      const source_weight =
        SOURCE_WEIGHTS[m.metadata?.source_type] ?? DEFAULT_SOURCE_WEIGHT;
      const recency = recency_factor(m.metadata?.date, now_seconds);
      const audience = audience_penalty(m.metadata?.url);
      return {
        ...m,
        adjusted_score: m.score * source_weight * recency * audience,
      };
    })
    .sort((a, b) => b.adjusted_score - a.adjusted_score);
}

function recency_factor(date_seconds, now_seconds) {
  if (!date_seconds || date_seconds <= 0) return 1.0;
  const age = Math.max(0, now_seconds - date_seconds);
  return Math.pow(0.5, age / RECENCY_HALF_LIFE_SECONDS);
}

// Guide pages under /global-team/ are maintainer-facing meta-docs
// (e.g. "Editing and publishing the Code of Conduct") and should rank
// below the canonical user-facing resources they describe.
function audience_penalty(url) {
  if (typeof url !== "string") return 1.0;
  return /\/global-team\//.test(url) ? 0.7 : 1.0;
}
