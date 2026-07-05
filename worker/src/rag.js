import { coding_decline_message, is_coding_question } from "./intent.js";
import { no_match_quip } from "./quips.js";

const EMBED_MODEL = "@cf/baai/bge-base-en-v1.5";
const CHAT_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";

const RETRIEVE_K = 20;
const EVENT_RETRIEVE_K = 15;
const TOP_K = 5;
const MIN_SCORE = 0.4;

// Below this reranked top score an answer still gets sent, but is logged as
// low_confidence — thin retrieval that likely means a corpus gap. Heuristic and
// tunable, not a hard cutoff; adjusted scores run roughly 0.3–0.9.
const LOW_CONFIDENCE_SCORE = 0.5;

const EVENT_RETRIEVAL_QUERY =
  "upcoming RLadies+ chapter event meetup workshop talk session when where";

// Bump the version suffix if EVENT_RETRIEVAL_QUERY changes or the embed
// model is swapped — the cached vector becomes stale instantly otherwise.
const EVENT_EMBEDDING_KV_KEY = "rag:event_embedding:v1";

const EVENT_INTENT_RE =
  /\b(event|events|meetup|meetups|workshop|workshops|talk|talks|session|sessions|happening|coming up|upcoming|soon|scheduled|next event|next meetup|when is the next|what.?s on|what.?s happening)\b/i;

// The cross-chapter upcoming-events digest built by the R indexer. It is a
// single chunk listing every upcoming event globally, soonest first — the
// only source that can answer "when is the next event, regardless of
// chapter". Pinned into context for event questions (see below).
const EVENTS_DIGEST_TYPE = "events-digest";

const SOURCE_WEIGHTS = {
  guide: 1.25,
  "events-digest": 1.5,
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
const STALENESS_GRACE_SECONDS = 365 * 24 * 60 * 60;
const STALENESS_FLOOR_SECONDS = 730 * 24 * 60 * 60;
const STALENESS_FLOOR = 0.85;
const UPCOMING_EVENT_BOOST = 1.6;

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
- Event entries include "When:" and "Status: upcoming" or "Status: past" lines. When the user asks about *upcoming*, *next*, or *coming up* events, only use chunks marked "Status: upcoming" and quote the "When:" date; ignore past events for that question. If no upcoming events are in the sources, say so honestly rather than substituting a past one.
- For "when is the next event" or "any upcoming events" questions — especially when the user does not name a chapter — prefer the source titled *Upcoming RLadies+ events*, which lists every upcoming event across all chapters soonest first. Answer with the soonest one (and a couple more if useful), quoting each date, and link to that specific event.

Linking (do this — it is not optional):
- Always include 1–2 inline Slack-formatted links in your answer, drawn from the URLs marked "Source URL:" in the material below. Wrap a relevant phrase, never a bare URL.
- Pick the source that most directly answers the question. Don't tack a link onto every sentence, and don't append a separate "Sources" section.
- Never invent URLs. Only link to URLs that appear verbatim under "Source URL:" below. If — and only if — none of the sources are relevant to the question, omit links.
- If a user asks "can you give me links / sources / where can I read more", treat that as a request to *include* links in your answer, not a yes/no question. Don't refuse.

Worked example (style only — the URLs and topic will differ):
Question: How do I start an RLadies+ chapter?
Answer: Chapters start by filling out the new-chapter form, then waiting for a Global Team review. You can find the full walkthrough in the <https://guide.rladies.org/organize/new-chapter/|new chapter guide>, and the application itself lives on the <https://rladies.org/about-us/start-rladies/|main RLadies+ site>.
`;

export async function rag_question_answer(env, query, history = []) {
  if (is_coding_question(query)) {
    return {
      answer: coding_decline_message(),
      outcome: "coding_declined",
      top_score: null,
      sources: null,
    };
  }

  const { retrieval_text, prior_messages } = rag_history_normalize(
    query,
    history,
  );
  const embedding = await rag_query_embed(env, retrieval_text);
  const matches = await rag_chunks_retrieve(env, embedding, query);

  if (matches.length === 0) {
    return {
      answer: no_match_quip(),
      outcome: "no_match",
      top_score: null,
      sources: null,
    };
  }

  const result = await env.AI.run(CHAT_MODEL, {
    messages: rag_build_messages(query, matches, prior_messages),
    max_tokens: 400,
  });

  const raw = (result.response || "").trim();
  const answer = rag_repair_links(raw, rag_source_urls(matches));
  const top_score = matches[0]?.adjusted_score ?? null;
  const outcome =
    top_score !== null && top_score < LOW_CONFIDENCE_SCORE
      ? "low_confidence"
      : "answered";
  return { answer, outcome, top_score, sources: rag_match_sources(matches) };
}

export function rag_match_sources(matches) {
  const types = [];
  for (const m of matches || []) {
    const t = m?.metadata?.source_type;
    if (t && !types.includes(t)) types.push(t);
  }
  return types.length ? types.join(",") : null;
}

const HISTORY_TURN_LIMIT = 8;
const HISTORY_CHAR_BUDGET = 4000;
const HISTORY_TURN_CHAR_LIMIT = 1500;
const RETRIEVAL_CONTEXT_USER_TURNS = 2;

export function rag_history_normalize(query, history) {
  if (!Array.isArray(history) || history.length === 0) {
    return { retrieval_text: query, prior_messages: [] };
  }

  const retrieval_extras = history
    .filter((m) => m.role === "user")
    .slice(-RETRIEVAL_CONTEXT_USER_TURNS)
    .map((m) => m.content)
    .join(" ");
  const retrieval_text = retrieval_extras
    ? `${retrieval_extras} ${query}`
    : query;

  const trimmed = history.slice(-HISTORY_TURN_LIMIT);
  let budget = HISTORY_CHAR_BUDGET;
  const prior_messages = [];
  for (let i = trimmed.length - 1; i >= 0; i--) {
    const m = trimmed[i];
    const content = (m.content || "").slice(0, HISTORY_TURN_CHAR_LIMIT);
    if (!content) continue;
    if (content.length > budget) continue;
    budget -= content.length;
    prior_messages.unshift({ role: m.role, content });
  }

  return { retrieval_text, prior_messages };
}

const BROKEN_SCHEME_RE = /<(ttps?:\/\/)/g;
const SLACK_LINK_RE = /<(https?:\/\/[^\s|>]+)\|([^>]+)>/g;

export function rag_repair_links(text, allowed_urls) {
  if (!text) return text;
  const allowed = new Set(allowed_urls || []);
  return text
    .replace(BROKEN_SCHEME_RE, "<h$1")
    .replace(SLACK_LINK_RE, (full, url, label) =>
      allowed.has(url) ? full : label.trim(),
    );
}

export function rag_build_messages(query, matches, prior_messages = []) {
  const context = matches
    .map((m, i) => {
      const heading = m.metadata.heading ? ` › ${m.metadata.heading}` : "";
      return `--- Source ${i + 1}: ${m.metadata.title}${heading}\nSource URL: ${m.metadata.url}\n\n${m.metadata.text}\n\n(Linkable as: <${m.metadata.url}|${m.metadata.title}>)`;
    })
    .join("\n\n");

  return [
    { role: "system", content: SYSTEM_PROMPT },
    ...prior_messages,
    {
      role: "user",
      content: `Question: ${query}\n\nSource material:\n${context}`,
    },
  ];
}

const DIGEST_LINK_RE = /<(https?:\/\/[^\s|>]+)\|/g;

export function rag_source_urls(matches) {
  const urls = [];
  for (const m of matches || []) {
    const url = m?.metadata?.url;
    if (typeof url === "string" && url.length > 0) urls.push(url);
    // The digest embeds a per-event link on every line. Harvest only the
    // URLs in <url|label> link position — the ones we intentionally emit —
    // so an attacker-influenced URL sitting in a title or venue (untrusted
    // feed content) can't slip past rag_repair_links' allow-list.
    if (is_digest_match(m) && typeof m?.metadata?.text === "string") {
      for (const match of m.metadata.text.matchAll(DIGEST_LINK_RE)) {
        urls.push(match[1]);
      }
    }
  }
  return urls;
}

async function rag_query_embed(env, text) {
  const result = await env.AI.run(EMBED_MODEL, {
    text: [text],
  });
  return result.data[0];
}

async function rag_chunks_retrieve(env, embedding, query) {
  const primary = await env.RAG_INDEX.query(embedding, {
    topK: RETRIEVE_K,
    returnMetadata: "all",
  });
  let raw = (primary.matches || []).filter((m) => m.score >= MIN_SCORE);

  if (is_event_question(query)) {
    const event_pool = await rag_event_pool_retrieve(env);
    raw = merge_matches(raw, event_pool);
    return select_event_matches(raw, Date.now() / 1000);
  }

  return rerank_matches(raw, Date.now() / 1000).slice(0, TOP_K);
}

function is_digest_match(m) {
  return m?.metadata?.source_type === EVENTS_DIGEST_TYPE;
}

// Reranking alone can bury the cross-chapter digest below individual
// events with marginally better cosine scores, and TOP_K truncation can
// drop it entirely — exactly the chunk an "regardless of chapter" event
// question needs most. Force the digest to the front so it always reaches
// the model, then fill the remaining slots with the best of the rest.
// There is one global digest by construction; cap at one so it can never
// starve the context of actual event/guide chunks.
export function select_event_matches(matches, now_seconds) {
  const ranked = rerank_matches(matches, now_seconds);
  const digests = ranked.filter(is_digest_match).slice(0, 1);
  const rest = ranked.filter((m) => !is_digest_match(m));
  return [...digests, ...rest].slice(0, TOP_K);
}

async function rag_event_pool_retrieve(env) {
  try {
    const embedding = await rag_event_embedding_get(env);
    const results = await env.RAG_INDEX.query(embedding, {
      topK: EVENT_RETRIEVE_K,
      returnMetadata: "all",
    });
    return (results.matches || []).filter(
      (m) =>
        (m.metadata?.source_type === "events" || is_digest_match(m)) &&
        m.score >= MIN_SCORE,
    );
  } catch (e) {
    console.warn("event-pool retrieval failed:", e.message);
    return [];
  }
}

async function rag_event_embedding_get(env) {
  if (env.SLACK_TOKENS) {
    const cached = await env.SLACK_TOKENS.get(
      EVENT_EMBEDDING_KV_KEY,
      "json",
    ).catch(() => null);
    if (Array.isArray(cached) && cached.length > 0) return cached;
  }
  const embedding = await rag_query_embed(env, EVENT_RETRIEVAL_QUERY);
  if (env.SLACK_TOKENS && Array.isArray(embedding)) {
    await env.SLACK_TOKENS.put(
      EVENT_EMBEDDING_KV_KEY,
      JSON.stringify(embedding),
      { expirationTtl: 30 * 24 * 60 * 60 },
    ).catch((e) =>
      console.warn("event-embedding cache write failed:", e.message),
    );
  }
  return embedding;
}

export function is_event_question(query) {
  if (!query || typeof query !== "string") return false;
  return EVENT_INTENT_RE.test(query);
}

export function merge_matches(primary, extra) {
  const seen = new Set(primary.map((m) => m.id));
  const merged = [...primary];
  for (const m of extra) {
    if (!seen.has(m.id)) {
      merged.push(m);
      seen.add(m.id);
    }
  }
  return merged;
}

export function rerank_matches(matches, now_seconds) {
  return matches
    .map((m) => {
      const source_weight =
        SOURCE_WEIGHTS[m.metadata?.source_type] ?? DEFAULT_SOURCE_WEIGHT;
      const recency = recency_factor(m.metadata?.date, now_seconds);
      const staleness = staleness_factor(m.metadata?.lastmod, now_seconds);
      const audience = audience_penalty(m.metadata?.url);
      const upcoming = upcoming_event_boost(
        m.metadata?.source_type,
        m.metadata?.date,
        now_seconds,
      );
      return {
        ...m,
        adjusted_score:
          m.score * source_weight * recency * staleness * audience * upcoming,
      };
    })
    .sort((a, b) => b.adjusted_score - a.adjusted_score);
}

function recency_factor(date_seconds, now_seconds) {
  if (!date_seconds || date_seconds <= 0) return 1.0;
  const age = Math.max(0, now_seconds - date_seconds);
  return Math.pow(0.5, age / RECENCY_HALF_LIFE_SECONDS);
}

// Rewards pages whose git history shows recent maintenance. Asymmetric and
// gentler than recency_factor: within the grace window it is a no-op, then
// tapers linearly to a floor — meant to break ties between near-equivalent
// matches without burying correct-but-untouched reference docs.
function staleness_factor(lastmod_seconds, now_seconds) {
  if (!lastmod_seconds || lastmod_seconds <= 0) return 1.0;
  const age = Math.max(0, now_seconds - lastmod_seconds);
  if (age <= STALENESS_GRACE_SECONDS) return 1.0;
  if (age >= STALENESS_FLOOR_SECONDS) return STALENESS_FLOOR;
  const span = STALENESS_FLOOR_SECONDS - STALENESS_GRACE_SECONDS;
  const t = (age - STALENESS_GRACE_SECONDS) / span;
  return 1.0 - t * (1.0 - STALENESS_FLOOR);
}

// Guide pages under /global-team/ are maintainer-facing meta-docs
// (e.g. "Editing and publishing the Code of Conduct") and should rank
// below the canonical user-facing resources they describe.
function audience_penalty(url) {
  if (typeof url !== "string") return 1.0;
  return /\/global-team\//.test(url) ? 0.7 : 1.0;
}

// Most event chunks in the index are past events kept on a 365d trailing
// window. Without this boost a past event with marginally better cosine
// similarity outranks the handful of genuinely upcoming events the user
// almost certainly meant to ask about.
function upcoming_event_boost(source_type, date_seconds, now_seconds) {
  if (source_type !== "events" && source_type !== EVENTS_DIGEST_TYPE) {
    return 1.0;
  }
  if (!date_seconds || date_seconds <= now_seconds) return 1.0;
  return UPCOMING_EVENT_BOOST;
}
