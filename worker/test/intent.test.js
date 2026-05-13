import { describe, it, expect } from "vitest";
import { coding_decline_message, is_coding_question } from "../src/intent.js";

describe("is_coding_question", () => {
  it("flags obvious coding questions", () => {
    const cases = [
      "How do I plot a histogram in R?",
      "Can you help me debug my dplyr pipeline?",
      "library(ggplot2)",
      "Error in lm(y ~ x) : 0 (non-NA) cases",
      "import pandas as pd",
      "What does p-value < 0.05 mean?",
      "write me a function that returns the median",
      "my regex isn't matching",
      "SELECT * FROM users WHERE active = 1",
    ];
    for (const q of cases) {
      expect(is_coding_question(q), `expected coding for: ${q}`).toBe(true);
    }
  });

  it("does not flag in-scope RLadies+ org questions", () => {
    const cases = [
      "What is RLadies+?",
      "How do I start an RLadies+ chapter?",
      "Where is the code of conduct?",
      "Is there a #help-r channel?",
      "What R packages does RLadies+ recommend for beginners?",
      "Who organises the RLadies+ Oslo chapter?",
      "When is the next RLadies+ event?",
      "How do I join the global team?",
      "Can I propose a talk at useR!?",
    ];
    for (const q of cases) {
      expect(is_coding_question(q), `expected non-coding for: ${q}`).toBe(false);
    }
  });

  it("returns false for empty or non-string input", () => {
    expect(is_coding_question("")).toBe(false);
    expect(is_coding_question("   ")).toBe(false);
    expect(is_coding_question(null)).toBe(false);
    expect(is_coding_question(undefined)).toBe(false);
  });
});

describe("coding_decline_message", () => {
  it("references #help-r and stays in character", () => {
    const msg = coding_decline_message();
    expect(msg).toMatch(/#help-r/);
    expect(msg).toMatch(/coding assistant/i);
  });
});
