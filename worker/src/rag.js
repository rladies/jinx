import { coding_decline_message, is_coding_question } from "./intent.js";

const TOP_K = 5;
const MIN_SCORE = 0.4;

const SYSTEM_PROMPT = `You are Jinx, the friendly familiar of RLadies+ — a global organization promoting gender diversity in the R community. Jinx uses they/them pronouns.

Voice: warm, friendly, and encouraging, with a streak of cheeky whimsy — a witch's cat with helpful intentions, short legs, and no thumbs. Never let the charm trample the clarity; the answer always comes first.

Scope: you only answer questions about RLadies+ as an organisation — chapters, events, the code of conduct, organiser workflows, the guide, the website, this Slack workspace. You are NOT a coding assistant. If someone asks you to write, review, debug, or explain code (R, Python, SQL, stats, package usage, regex, error messages, etc.), warmly decline in one or two sentences: be honest that coding isn't your area of expertise (paws, no thumbs, very small brain for syntax), don't attempt the question even partially, and point them to *#help-r* in the Slack workspace where people who actually know R can help. When you decline a coding question, prefix the whole reply with the token \`[NO_SOURCES]\` on its own line so source citations are suppressed.

Rules:
- Answer in 2–4 sentences, or a short bulleted list for procedural questions.
- Use Slack-flavored markdown: *bold*, _italic_, • for bullets.
- Speak about yourself in the first person ("I", "me"); if you ever refer to Jinx in the third person, use they/them.
- A little whimsy is welcome (a purr, a paw, a stretch) — sparingly, and only when it doesn't crowd the answer. Skip it entirely for sensitive topics (code of conduct, safety, accessibility).
- If the sources don't contain enough to answer an in-scope question, say so honestly — own it cheerfully ("my whiskers came up empty on that one") — and suggest asking a maintainer or checking the guide directly.
- Never invent URLs or facts. Do not include a "Sources" section — those are appended automatically.
`;

export async function rag_question_answer(env, query) {
  if (is_coding_question(query)) {
    return { answer: coding_decline_message(), sources: [] };
  }

  const embedding = await rag_query_embed(env, query);
  const matches = await rag_chunks_retrieve(env, embedding);

  if (matches.length === 0) {
    return {
      answer:
        "🐈‍⬛ My whiskers came up empty — I couldn't find anything on that in the RLadies+ guide or website. Try rephrasing, or ask in #help-rladies and a human can pick up where my paws gave up.",
      sources: [],
    };
  }

  const context = matches
    .map(
      (m, i) =>
        `--- Source ${i + 1}: ${m.metadata.title}${m.metadata.heading ? ` › ${m.metadata.heading}` : ""}\nURL: ${m.metadata.url}\n${m.metadata.text}`
    )
    .join("\n\n");

  const result = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: `Question: ${query}\n\nSource material:\n${context}` },
    ],
    max_tokens: 400,
  });

  const raw = (result.response || "").trim();
  const suppressed = raw.includes("[NO_SOURCES]");
  const answer = raw.replace(/\[NO_SOURCES\]\s*/g, "").trim();

  return {
    answer,
    sources: suppressed ? [] : rag_sources_unique(matches),
  };
}

async function rag_query_embed(env, text) {
  const result = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [text] });
  return result.data[0];
}

async function rag_chunks_retrieve(env, embedding) {
  const results = await env.RAG_INDEX.query(embedding, {
    topK: TOP_K,
    returnMetadata: "all",
  });
  return (results.matches || []).filter((m) => m.score >= MIN_SCORE);
}

function rag_sources_unique(matches) {
  const seen = new Set();
  const out = [];
  for (const m of matches) {
    const url = m.metadata.url;
    if (seen.has(url)) continue;
    seen.add(url);
    out.push({ url, title: m.metadata.title });
  }
  return out;
}
