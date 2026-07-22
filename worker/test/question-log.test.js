import { describe, it, expect } from "vitest";
import {
  question_capture,
  question_log_since,
  question_log_purge,
  question_gaps_rank,
  question_downvoted_rank,
} from "../src/question-log.js";
import { makeKv, makeD1 } from "./_helpers.js";

function makeEnv({ d1 = makeD1(), kv = makeKv() } = {}) {
  return { QUESTION_LOG: d1, SLACK_TOKENS: kv };
}

describe("question_capture", () => {
  it("stores an anonymous row with no identifiers", async () => {
    const env = makeEnv();
    const id = await question_capture(env, {
      teamId: "T1",
      channel: "C1",
      answerTs: "1.5",
      question: "how do I start a chapter?",
      outcome: "answered",
      top_score: 0.82,
      sources: "guide,site",
    });
    expect(id).toBe(1);
    const row = env.QUESTION_LOG._rows[0];
    expect(row.question).toBe("how do I start a chapter?");
    expect(row.outcome).toBe("answered");
    expect(Object.keys(row)).not.toContain("user");
    expect(Object.keys(row)).not.toContain("channel");
  });

  it("links the answer message to the row for later voting", async () => {
    const env = makeEnv();
    const id = await question_capture(env, {
      teamId: "T1",
      channel: "C1",
      answerTs: "1.5",
      question: "q",
      outcome: "answered",
      top_score: 0.7,
      sources: "guide",
    });
    const linked = await env.SLACK_TOKENS.get("answer_link:T1:C1:1.5");
    expect(linked).toBe(String(id));
  });

  it("truncates very long questions", async () => {
    const env = makeEnv();
    await question_capture(env, {
      teamId: "T1",
      channel: "C1",
      answerTs: "1.5",
      question: "x".repeat(900),
      outcome: "no_match",
    });
    expect(env.QUESTION_LOG._rows[0].question.length).toBe(500);
  });

  it("skips linking when the answer had no single message ts", async () => {
    const env = makeEnv();
    await question_capture(env, {
      teamId: "T1",
      channel: "C1",
      answerTs: null,
      question: "q",
      outcome: "answered",
    });
    expect(await env.SLACK_TOKENS.get("answer_link:T1:C1:null")).toBeNull();
  });

  it("no-ops without a D1 binding", async () => {
    const id = await question_capture(
      { SLACK_TOKENS: makeKv() },
      { teamId: "T1", channel: "C1", answerTs: "1.5", question: "q", outcome: "answered" },
    );
    expect(id).toBeNull();
  });

  it("does not store empty questions", async () => {
    const env = makeEnv();
    const id = await question_capture(env, {
      teamId: "T1",
      channel: "C1",
      answerTs: "1.5",
      question: "   ",
      outcome: "answered",
    });
    expect(id).toBeNull();
    expect(env.QUESTION_LOG._rows).toHaveLength(0);
  });
});

describe("question_gaps_rank", () => {
  it("keeps only gap outcomes and folds near-duplicates by count", () => {
    const rows = [
      { question: "How do I get a swag budget?", outcome: "no_match" },
      { question: "how do i get a swag budget?", outcome: "no_match" },
      { question: "review my code", outcome: "coding_declined" },
      { question: "what is a chapter?", outcome: "answered" },
    ];
    const gaps = question_gaps_rank(rows);
    expect(gaps).toHaveLength(2);
    expect(gaps[0].count).toBe(2);
    expect(gaps.some((g) => g.outcome === "answered")).toBe(false);
  });
});

describe("question_downvoted_rank", () => {
  it("surfaces answers with net-negative reactions, worst first", () => {
    const rows = [
      { question: "a", outcome: "answered", up: 0, down: 3 },
      { question: "b", outcome: "answered", up: 2, down: 2 },
      { question: "c", outcome: "answered", up: 1, down: 2 },
    ];
    const out = question_downvoted_rank(rows);
    expect(out.map((r) => r.question)).toEqual(["a", "c"]);
  });
});

describe("question_log_since", () => {
  it("returns rows within the window", async () => {
    const d1 = makeD1([
      { day: "2026-07-01", question: "recent", outcome: "answered" },
      { day: "2026-01-01", question: "old", outcome: "answered" },
    ]);
    const rows = await question_log_since({ QUESTION_LOG: d1 }, "2026-06-01");
    expect(rows.map((r) => r.question)).toEqual(["recent"]);
  });

  it("returns empty without a binding", async () => {
    expect(await question_log_since({}, "2026-06-01")).toEqual([]);
  });
});

describe("question_log_purge", () => {
  it("deletes rows older than the retention window", async () => {
    const d1 = makeD1([
      { day: "2026-07-01", question: "keep", outcome: "answered" },
      { day: "2020-01-01", question: "drop", outcome: "answered" },
    ]);
    const deleted = await question_log_purge({ QUESTION_LOG: d1 }, 180);
    expect(deleted).toBe(1);
    expect(d1._rows.map((r) => r.question)).toEqual(["keep"]);
  });

  it("no-ops without a binding", async () => {
    expect(await question_log_purge({}, 180)).toBe(0);
  });
});
