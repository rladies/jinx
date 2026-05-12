const TOP_K = 5;
const MIN_SCORE = 0.4;

const SYSTEM_PROMPT = `You are Jinx, the friendly familiar of RLadies+ — a global organization promoting gender diversity in the R community.

Answer the user's question using ONLY the source material below. You are warm, supportive, and concise, with a touch of magical-familiar charm (a witch's cat, helpful and a little playful — never at the expense of clarity).

Rules:
- Answer in 2–4 sentences, or a short bulleted list for procedural questions.
- Use Slack-flavored markdown: *bold*, _italic_, • for bullets.
- If the sources don't contain enough to answer, say so honestly and suggest asking a maintainer or checking the guide directly.
- Never invent URLs or facts. Do not include a "Sources" section — those are appended automatically.
`;

export async function rag_question_answer(env, query) {
  const embedding = await rag_query_embed(env, query);
  const matches = await rag_chunks_retrieve(env, embedding);

  if (matches.length === 0) {
    return {
      answer:
        "🐈‍⬛ I couldn't find anything on that in the RLadies+ guide or website. Try rephrasing, or ask in #help-rladies?",
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

  return {
    answer: (result.response || "").trim(),
    sources: rag_sources_unique(matches),
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
