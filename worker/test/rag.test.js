import { describe, it, expect } from "vitest";
import { rerank_matches } from "../src/rag.js";

const NOW = 1_715_000_000;
const ONE_YEAR = 365 * 24 * 60 * 60;

function match({ id, score, source_type, date = 0 }) {
  return { id, score, metadata: { source_type, date } };
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
});
