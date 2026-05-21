import { describe, it, expect } from "vitest";
import {
  rag_build_messages,
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

  it("boosts upcoming events (future date clamps recency to 1.0)", () => {
    const upcoming = match({
      id: "upcoming",
      score: 0.7,
      source_type: "events",
      date: NOW + 30 * 24 * 60 * 60,
    });
    const [out] = rerank_matches([upcoming], NOW);
    expect(out.adjusted_score).toBeCloseTo(0.7 * 1.05, 5);
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
