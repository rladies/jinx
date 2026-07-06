import { describe, it, expect, vi, afterEach } from "vitest";

vi.mock("../src/question-log.js", async (importOriginal) => {
  const actual = await importOriginal();
  return { ...actual, question_log_since: vi.fn() };
});

import { question_log_since } from "../src/question-log.js";
import {
  content_gaps,
  coding_declined_count,
  draft_guide_snippet,
  format_digest,
  question_digest_build,
  question_digest_post,
} from "../src/question-digest.js";
import { makeKv } from "./_helpers.js";

afterEach(() => vi.restoreAllMocks());

function aiEnv(response = "Chapters start with the form.") {
  return { AI: { run: vi.fn(async () => ({ response })) } };
}

describe("content_gaps", () => {
  const rows = [
    { question: "swag budget?", outcome: "no_match" },
    { question: "Swag  budget?", outcome: "no_match" },
    { question: "review my code", outcome: "coding_declined" },
    { question: "best venue tips", outcome: "low_confidence" },
    { question: "what is a chapter", outcome: "answered" },
  ];

  it("keeps no_match + low_confidence, drops coding_declined and answered", () => {
    const gaps = content_gaps(rows);
    const qs = gaps.map((g) => g.question.toLowerCase());
    expect(qs.some((q) => q.includes("review my code"))).toBe(false);
    expect(qs.some((q) => q.includes("what is a chapter"))).toBe(false);
    expect(gaps.some((g) => /venue/i.test(g.question))).toBe(true);
  });

  it("folds near-duplicates and counts them", () => {
    const swag = content_gaps(rows).find((g) => /swag/i.test(g.question));
    expect(swag.count).toBe(2);
  });

  it("honours minCount", () => {
    const gaps = content_gaps(rows, { minCount: 2 });
    expect(gaps).toHaveLength(1);
    expect(gaps[0].question).toMatch(/swag/i);
  });
});

describe("coding_declined_count", () => {
  it("counts only coding declines", () => {
    expect(
      coding_declined_count([
        { outcome: "coding_declined" },
        { outcome: "coding_declined" },
        { outcome: "no_match" },
      ]),
    ).toBe(2);
  });
});

describe("draft_guide_snippet", () => {
  it("returns the trimmed model response", async () => {
    const env = aiEnv("  A short draft.  ");
    expect(await draft_guide_snippet(env, "q")).toBe("A short draft.");
  });

  it("returns null on an empty response", async () => {
    expect(await draft_guide_snippet(aiEnv(""), "q")).toBeNull();
  });

  it("returns null when the model call throws", async () => {
    const env = {
      AI: {
        run: vi.fn(async () => {
          throw new Error("AI down");
        }),
      },
    };
    expect(await draft_guide_snippet(env, "q")).toBeNull();
  });
});

describe("format_digest", () => {
  it("renders gaps, drafts, downvotes, coding FYI, and the unverified footer", () => {
    const text = format_digest({
      days: 7,
      total: 12,
      gaps: [{ question: "swag budget", outcome: "no_match", count: 3 }],
      drafts: [
        { question: "swag budget", count: 3, draft: "Chapters can request a budget." },
      ],
      downvoted: [{ question: "how to renew", up: 0, down: 2 }],
      codingCount: 4,
    });
    expect(text).toMatch(/swag budget/);
    expect(text).toMatch(/draft:/);
    expect(text).toMatch(/Chapters can request a budget/);
    expect(text).toMatch(/how to renew/);
    expect(text).toMatch(/declined 4 coding/i);
    expect(text).toMatch(/unverified/i);
  });

  it("says so when there are no gaps", () => {
    const text = format_digest({
      days: 7,
      total: 3,
      gaps: [],
      drafts: [],
      downvoted: [],
      codingCount: 0,
    });
    expect(text).toMatch(/none this week/i);
  });
});

describe("question_digest_build", () => {
  it("builds a digest from logged rows", async () => {
    question_log_since.mockResolvedValue([
      { question: "swag budget?", outcome: "no_match" },
      { question: "swag budget?", outcome: "no_match" },
      { question: "review my code", outcome: "coding_declined" },
    ]);
    const env = { QUESTION_LOG: {}, ...aiEnv("Chapters can request a swag budget.") };
    const text = await question_digest_build(env, { days: 7 });
    expect(text).toMatch(/swag budget/i);
    expect(text).toMatch(/draft:/);
    expect(text).toMatch(/declined 1 coding/i);
  });

  it("returns null when nothing was logged", async () => {
    question_log_since.mockResolvedValue([]);
    const env = { QUESTION_LOG: {}, ...aiEnv() };
    expect(await question_digest_build(env, { days: 7 })).toBeNull();
  });

  it("returns null without a D1 binding", async () => {
    expect(await question_digest_build({ ...aiEnv() }, { days: 7 })).toBeNull();
  });
});

describe("question_digest_post", () => {
  function orgEnv() {
    return {
      QUESTION_LOG: {},
      SLACK_ORGANIZER_TEAM_ID: "T_ORG",
      SLACK_TOKENS: makeKv({
        "team:T_ORG": JSON.stringify({ bot_token: "xoxb" }),
        "channel_index:T_ORG": JSON.stringify({
          names: { "team-jinx": "C_JINX" },
        }),
      }),
      ...aiEnv("A short draft."),
    };
  }

  it("posts the digest to the configured channel", async () => {
    question_log_since.mockResolvedValue([
      { question: "swag budget?", outcome: "no_match" },
    ]);
    const posts = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
      if (String(url).includes("chat.postMessage")) {
        posts.push(JSON.parse(init.body));
        return new Response(JSON.stringify({ ok: true, ts: "1" }), {
          status: 200,
        });
      }
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    });

    const ok = await question_digest_post(orgEnv(), { days: 7 });
    expect(ok).toBe(true);
    expect(posts).toHaveLength(1);
    expect(posts[0].channel).toBe("C_JINX");
    expect(posts[0].text).toMatch(/swag budget/i);
  });

  it("no-ops when there is nothing to report", async () => {
    question_log_since.mockResolvedValue([]);
    const ok = await question_digest_post(orgEnv(), { days: 7 });
    expect(ok).toBe(false);
  });

  it("no-ops when no organiser workspace is configured", async () => {
    question_log_since.mockResolvedValue([{ question: "q", outcome: "no_match" }]);
    const ok = await question_digest_post({ QUESTION_LOG: {}, ...aiEnv() }, {
      days: 7,
    });
    expect(ok).toBe(false);
  });
});
