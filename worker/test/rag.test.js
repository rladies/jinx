import { describe, it, expect, vi } from "vitest";
import {
  is_event_question,
  merge_matches,
  rag_build_messages,
  rag_question_answer,
  rag_repair_links,
  rag_source_urls,
  rerank_matches,
} from "../src/rag.js";

const NOW = 1_715_000_000;
const ONE_YEAR = 365 * 24 * 60 * 60;

function match({ id, score, source_type, date = 0, lastmod = 0, url = "" }) {
  return { id, score, metadata: { source_type, date, lastmod, url } };
}

describe("rerank_matches", () => {
  it("ranks guide content above github-org content at equal cosine score", () => {
    const out = rerank_matches(
      [
        match({ id: "gh", score: 0.8, source_type: "github-org" }),
        match({ id: "guide", score: 0.8, source_type: "guide" }),
      ],
      NOW
    );
    expect(out[0].id).toBe("guide");
    expect(out[1].id).toBe("gh");
  });

  it("treats missing date as evergreen (factor 1.0)", () => {
    const out = rerank_matches(
      [match({ id: "x", score: 0.7, source_type: "guide", date: 0 })],
      NOW
    );
    expect(out[0].adjusted_score).toBeCloseTo(0.7 * 1.25, 5);
  });

  it("decays older dated content with a two-year half-life", () => {
    const fresh = match({
      id: "fresh",
      score: 0.7,
      source_type: "site",
      date: NOW,
    });
    const old = match({
      id: "old",
      score: 0.7,
      source_type: "site",
      date: NOW - 2 * ONE_YEAR,
    });
    const out = rerank_matches([fresh, old], NOW);
    expect(out[0].id).toBe("fresh");
    expect(out[1].adjusted_score).toBeCloseTo(out[0].adjusted_score * 0.5, 4);
  });

  it("can let a high-cosine github match beat a low-cosine guide match", () => {
    const out = rerank_matches(
      [
        match({ id: "guide-weak", score: 0.45, source_type: "guide" }),
        match({ id: "gh-strong", score: 0.85, source_type: "github-org" }),
      ],
      NOW
    );
    expect(out[0].id).toBe("gh-strong");
  });

  it("falls back to default weight for unknown source_type", () => {
    const out = rerank_matches(
      [match({ id: "x", score: 0.6, source_type: "mystery" })],
      NOW
    );
    expect(out[0].adjusted_score).toBeCloseTo(0.6, 5);
  });

  it("boosts upcoming events with a 1.6× multiplier on top of the source weight", () => {
    const upcoming = match({
      id: "upcoming",
      score: 0.7,
      source_type: "events",
      date: NOW + 30 * 24 * 60 * 60,
    });
    const [out] = rerank_matches([upcoming], NOW);
    expect(out.adjusted_score).toBeCloseTo(0.7 * 1.05 * 1.6, 5);
  });

  it("does not boost past events (no upcoming multiplier when date <= now)", () => {
    const past = match({
      id: "past",
      score: 0.7,
      source_type: "events",
      date: NOW - 30 * 24 * 60 * 60,
    });
    const [out] = rerank_matches([past], NOW);
    const recency = Math.pow(0.5, (30 * 24 * 60 * 60) / (730 * 24 * 60 * 60));
    expect(out.adjusted_score).toBeCloseTo(0.7 * 1.05 * recency, 5);
  });

  it("ranks an upcoming event above a past event at equal cosine score", () => {
    const out = rerank_matches(
      [
        match({
          id: "past",
          score: 0.8,
          source_type: "events",
          date: NOW - 60 * 24 * 60 * 60,
        }),
        match({
          id: "upcoming",
          score: 0.8,
          source_type: "events",
          date: NOW + 7 * 24 * 60 * 60,
        }),
      ],
      NOW
    );
    expect(out[0].id).toBe("upcoming");
    expect(out[1].id).toBe("past");
  });

  it("ranks an upcoming event above a community creation at equal cosine score", () => {
    const out = rerank_matches(
      [
        match({ id: "creation", score: 0.8, source_type: "awesome-creations" }),
        match({
          id: "event",
          score: 0.8,
          source_type: "events",
          date: NOW + 7 * 24 * 60 * 60,
        }),
      ],
      NOW
    );
    expect(out[0].id).toBe("event");
    expect(out[1].id).toBe("creation");
  });

  it("does not apply the upcoming boost to non-event sources with a future date", () => {
    const [out] = rerank_matches(
      [
        match({
          id: "site",
          score: 0.7,
          source_type: "site",
          date: NOW + 30 * 24 * 60 * 60,
        }),
      ],
      NOW
    );
    expect(out.adjusted_score).toBeCloseTo(0.7 * 1.05, 5);
  });

  it("applies the youtube source weight (0.9)", () => {
    const [out] = rerank_matches(
      [match({ id: "y", score: 0.8, source_type: "youtube" })],
      NOW
    );
    expect(out.adjusted_score).toBeCloseTo(0.8 * 0.9, 5);
  });

  it("ranks the canonical CoC above its maintainer meta-doc at equal cosine score", () => {
    const out = rerank_matches(
      [
        match({
          id: "meta",
          score: 0.8,
          source_type: "guide",
          url: "https://guide.rladies.org/global-team/code-of-conduct/",
        }),
        match({
          id: "canonical",
          score: 0.8,
          source_type: "site",
          url: "https://rladies.org/coc/",
        }),
      ],
      NOW
    );
    expect(out[0].id).toBe("canonical");
    expect(out[1].id).toBe("meta");
  });

  it("applies a 0.7 multiplier to /global-team/ URLs", () => {
    const [penalised] = rerank_matches(
      [
        match({
          id: "g",
          score: 0.8,
          source_type: "guide",
          url: "https://guide.rladies.org/global-team/jinx/",
        }),
      ],
      NOW
    );
    expect(penalised.adjusted_score).toBeCloseTo(0.8 * 1.25 * 0.7, 5);
  });

  it("does not penalise non-/global-team/ guide pages", () => {
    const [unaffected] = rerank_matches(
      [
        match({
          id: "g",
          score: 0.8,
          source_type: "guide",
          url: "https://guide.rladies.org/organizers/intro/get-started/",
        }),
      ],
      NOW
    );
    expect(unaffected.adjusted_score).toBeCloseTo(0.8 * 1.25, 5);
  });

  it("treats lastmod within the 1y grace window as fully maintained", () => {
    const [fresh] = rerank_matches(
      [
        match({
          id: "fresh",
          score: 0.8,
          source_type: "site",
          lastmod: NOW - 6 * 30 * 24 * 60 * 60,
        }),
      ],
      NOW
    );
    expect(fresh.adjusted_score).toBeCloseTo(0.8 * 1.05, 5);
  });

  it("floors staleness at 0.85 once lastmod is two or more years old", () => {
    const [stale] = rerank_matches(
      [
        match({
          id: "stale",
          score: 0.8,
          source_type: "site",
          lastmod: NOW - 3 * ONE_YEAR,
        }),
      ],
      NOW
    );
    expect(stale.adjusted_score).toBeCloseTo(0.8 * 1.05 * 0.85, 5);
  });

  it("breaks ties between equally relevant chunks by lastmod", () => {
    const out = rerank_matches(
      [
        match({
          id: "untouched",
          score: 0.8,
          source_type: "site",
          lastmod: NOW - 3 * ONE_YEAR,
        }),
        match({
          id: "maintained",
          score: 0.8,
          source_type: "site",
          lastmod: NOW - 30 * 24 * 60 * 60,
        }),
      ],
      NOW
    );
    expect(out[0].id).toBe("maintained");
    expect(out[1].id).toBe("untouched");
  });

  it("treats missing lastmod as evergreen (factor 1.0)", () => {
    const [x] = rerank_matches(
      [match({ id: "x", score: 0.7, source_type: "guide", lastmod: 0 })],
      NOW
    );
    expect(x.adjusted_score).toBeCloseTo(0.7 * 1.25, 5);
  });
});

describe("rag_build_messages", () => {
  const sample_match = {
    metadata: {
      title: "Code of Conduct",
      heading: "Reporting",
      url: "https://rladies.org/coc/",
      text: "Reports can go to safety@rladies.org.",
    },
  };

  it("emits a system + user message pair", () => {
    const messages = rag_build_messages("how do i report?", [sample_match]);
    expect(messages).toHaveLength(2);
    expect(messages[0].role).toBe("system");
    expect(messages[1].role).toBe("user");
  });

  it("inlines the source URL into the user prompt", () => {
    const messages = rag_build_messages("how do i report?", [sample_match]);
    expect(messages[1].content).toContain("https://rladies.org/coc/");
    expect(messages[1].content).toContain("Code of Conduct");
    expect(messages[1].content).toContain("Reporting");
  });

  it("instructs Slack hyperlink syntax in the system prompt", () => {
    const [system] = rag_build_messages("anything", [sample_match]);
    expect(system.content).toMatch(/<https:\/\/example\.com\|readable label>/);
  });
});

describe("rag_repair_links", () => {
  const allowed = ["https://guide.rladies.org/coc/", "https://rladies.org/"];

  it("repairs <ttps:// to <https:// before validating", () => {
    const out = rag_repair_links(
      "See the <ttps://guide.rladies.org/coc/|Code of Conduct>.",
      allowed
    );
    expect(out).toBe(
      "See the <https://guide.rladies.org/coc/|Code of Conduct>."
    );
  });

  it("repairs <ttp:// to <http:// for non-https sources", () => {
    const out = rag_repair_links(
      "See <ttp://example.org|example>.",
      ["http://example.org"]
    );
    expect(out).toBe("See <http://example.org|example>.");
  });

  it("strips invented URLs but keeps the label", () => {
    const out = rag_repair_links(
      "Check <https://invented.example/page|the made-up guide> for details.",
      allowed
    );
    expect(out).toBe("Check the made-up guide for details.");
  });

  it("keeps links whose URL is in the allowlist", () => {
    const out = rag_repair_links(
      "Read the <https://rladies.org/|main site>.",
      allowed
    );
    expect(out).toBe("Read the <https://rladies.org/|main site>.");
  });

  it("handles a mix of repair, allowed, and invented in one answer", () => {
    const out = rag_repair_links(
      "Try the <ttps://guide.rladies.org/coc/|CoC>, the <https://rladies.org/|site>, and the <https://nope.example|imaginary doc>.",
      allowed
    );
    expect(out).toBe(
      "Try the <https://guide.rladies.org/coc/|CoC>, the <https://rladies.org/|site>, and the imaginary doc."
    );
  });

  it("returns empty input unchanged", () => {
    expect(rag_repair_links("", allowed)).toBe("");
  });

  it("treats a missing allowlist as no allowed URLs (strips every link)", () => {
    const out = rag_repair_links(
      "See <https://rladies.org/|the site>.",
      undefined
    );
    expect(out).toBe("See the site.");
  });
});

describe("rag_source_urls", () => {
  it("returns only well-formed URLs from match metadata", () => {
    const urls = rag_source_urls([
      { metadata: { url: "https://a.example" } },
      { metadata: { url: "" } },
      { metadata: {} },
      { metadata: { url: "https://b.example" } },
      {},
    ]);
    expect(urls).toEqual(["https://a.example", "https://b.example"]);
  });
});

describe("is_event_question", () => {
  it("matches direct event vocabulary", () => {
    expect(is_event_question("any upcoming events?")).toBe(true);
    expect(is_event_question("what events are coming up?")).toBe(true);
    expect(is_event_question("when is the next meetup?")).toBe(true);
    expect(is_event_question("are there any workshops soon?")).toBe(true);
    expect(is_event_question("what's happening this month?")).toBe(true);
  });

  it("matches event-noun queries even without a time qualifier", () => {
    expect(is_event_question("any events in London?")).toBe(true);
    expect(is_event_question("what meetups do we have?")).toBe(true);
  });

  it("does not match unrelated questions", () => {
    expect(is_event_question("how do I start a chapter?")).toBe(false);
    expect(is_event_question("where is the code of conduct?")).toBe(false);
    expect(is_event_question("")).toBe(false);
    expect(is_event_question(null)).toBe(false);
    expect(is_event_question(undefined)).toBe(false);
  });
});

describe("rag_question_answer dual retrieval", () => {
  function makeKv(initial = {}) {
    const store = new Map(Object.entries(initial));
    return {
      async get(key, mode) {
        if (!store.has(key)) return null;
        const raw = store.get(key);
        return mode === "json" ? JSON.parse(raw) : raw;
      },
      async put(key, value) {
        store.set(key, typeof value === "string" ? value : JSON.stringify(value));
      },
      _dump() {
        return Object.fromEntries(store);
      },
    };
  }

  function makeMockEnv({
    primaryMatches,
    eventMatches,
    llmResponse = "OK",
    kv = makeKv(),
  } = {}) {
    const queryCalls = [];
    const aiCalls = [];
    return {
      env: {
        SLACK_TOKENS: kv,
        AI: {
          run: vi.fn(async (model, body) => {
            aiCalls.push({ model, body });
            if (model === "@cf/baai/bge-base-en-v1.5") {
              return { data: [[0.1, 0.2, 0.3]] };
            }
            return { response: llmResponse };
          }),
        },
        RAG_INDEX: {
          query: vi.fn(async (_emb, opts) => {
            queryCalls.push(opts);
            return queryCalls.length === 1
              ? { matches: primaryMatches }
              : { matches: eventMatches };
          }),
        },
      },
      queryCalls,
      aiCalls,
      kv,
    };
  }

  it("issues only one index query for non-event questions", async () => {
    const { env, queryCalls } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.8,
          metadata: { url: "https://x", title: "T", text: "t", source_type: "guide" },
        },
      ],
      eventMatches: [],
    });
    await rag_question_answer(env, "how do I start a chapter?");
    expect(queryCalls).toHaveLength(1);
  });

  it("issues a second event-pool query for event questions", async () => {
    const { env, queryCalls, aiCalls } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.8,
          metadata: { url: "https://x", title: "T", text: "t", source_type: "guide" },
        },
      ],
      eventMatches: [
        {
          id: "e1",
          score: 0.6,
          metadata: {
            url: "https://meetup/e1",
            title: "Upcoming workshop",
            text: "Status: upcoming",
            source_type: "events",
            date: Date.now() / 1000 + 86400,
          },
        },
      ],
    });
    await rag_question_answer(env, "any upcoming events?");
    expect(queryCalls).toHaveLength(2);
    expect(aiCalls.filter((c) => c.model === "@cf/baai/bge-base-en-v1.5")).toHaveLength(2);
  });

  it("surfaces upcoming events from the event pool when the primary query misses them", async () => {
    const llmInputs = [];
    const { env } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.7,
          metadata: { url: "https://guide", title: "Guide", text: "guide text", source_type: "guide" },
        },
      ],
      eventMatches: [
        {
          id: "e1",
          score: 0.55,
          metadata: {
            url: "https://meetup/e1",
            title: "RLadies+ London — June workshop",
            text: "Status: upcoming\nWhen: 2026-06-15",
            source_type: "events",
            date: Date.now() / 1000 + 30 * 86400,
          },
        },
      ],
    });
    env.AI.run = vi.fn(async (model, body) => {
      if (model === "@cf/baai/bge-base-en-v1.5") return { data: [[0.1]] };
      llmInputs.push(body);
      return { response: "OK" };
    });
    await rag_question_answer(env, "any upcoming events?");
    const userMsg = llmInputs[0].messages.find((m) => m.role === "user").content;
    expect(userMsg).toContain("RLadies+ London — June workshop");
  });

  it("caches the event-pool embedding in KV after the first call", async () => {
    const kv = makeKv();
    const { env, aiCalls } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.8,
          metadata: { url: "https://g", title: "G", text: "g", source_type: "guide" },
        },
      ],
      eventMatches: [
        {
          id: "e1",
          score: 0.6,
          metadata: {
            url: "https://meetup/e1",
            title: "Workshop",
            text: "Status: upcoming",
            source_type: "events",
            date: Date.now() / 1000 + 86400,
          },
        },
      ],
      kv,
    });
    await rag_question_answer(env, "any upcoming events?");
    const embedCallsAfterFirst = aiCalls.filter(
      (c) => c.model === "@cf/baai/bge-base-en-v1.5"
    ).length;
    expect(embedCallsAfterFirst).toBe(2);
    expect(kv._dump()["rag:event_embedding:v1"]).toBeTruthy();

    await rag_question_answer(env, "next meetup?");
    const embedCallsAfterSecond = aiCalls.filter(
      (c) => c.model === "@cf/baai/bge-base-en-v1.5"
    ).length;
    expect(embedCallsAfterSecond).toBe(3);
  });

  it("falls back to a fresh embed when the cached value is corrupt", async () => {
    const kv = makeKv({ "rag:event_embedding:v1": "not-an-array" });
    const { env, aiCalls } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.8,
          metadata: { url: "https://g", title: "G", text: "g", source_type: "guide" },
        },
      ],
      eventMatches: [
        {
          id: "e1",
          score: 0.6,
          metadata: {
            url: "https://meetup/e1",
            title: "W",
            text: "Status: upcoming",
            source_type: "events",
            date: Date.now() / 1000 + 86400,
          },
        },
      ],
      kv,
    });
    await rag_question_answer(env, "any upcoming events?");
    const embedCalls = aiCalls.filter(
      (c) => c.model === "@cf/baai/bge-base-en-v1.5"
    ).length;
    expect(embedCalls).toBe(2);
  });

  it("filters event-pool results to source_type=events", async () => {
    const { env, queryCalls } = makeMockEnv({
      primaryMatches: [
        {
          id: "g1",
          score: 0.8,
          metadata: { url: "https://g", title: "G", text: "g", source_type: "guide" },
        },
      ],
      eventMatches: [
        {
          id: "y1",
          score: 0.9,
          metadata: { url: "https://y", title: "Y", text: "y", source_type: "youtube" },
        },
      ],
    });
    const llmInputs = [];
    env.AI.run = vi.fn(async (model, body) => {
      if (model === "@cf/baai/bge-base-en-v1.5") return { data: [[0.1]] };
      llmInputs.push(body);
      return { response: "OK" };
    });
    await rag_question_answer(env, "any upcoming events?");
    expect(queryCalls).toHaveLength(2);
    const userMsg = llmInputs[0].messages.find((m) => m.role === "user").content;
    expect(userMsg).not.toContain("y1");
    expect(userMsg).not.toContain("Title: Y");
  });
});

describe("merge_matches", () => {
  it("appends extras not already present and dedupes by id", () => {
    const primary = [
      { id: "a", score: 0.8, metadata: {} },
      { id: "b", score: 0.7, metadata: {} },
    ];
    const extra = [
      { id: "b", score: 0.9, metadata: {} },
      { id: "c", score: 0.6, metadata: {} },
    ];
    const merged = merge_matches(primary, extra);
    expect(merged.map((m) => m.id)).toEqual(["a", "b", "c"]);
    expect(merged.find((m) => m.id === "b").score).toBe(0.7);
  });

  it("preserves primary order", () => {
    const primary = [
      { id: "x", score: 0.9, metadata: {} },
      { id: "y", score: 0.8, metadata: {} },
    ];
    const merged = merge_matches(primary, []);
    expect(merged.map((m) => m.id)).toEqual(["x", "y"]);
  });
});
