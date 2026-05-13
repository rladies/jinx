import { describe, it, expect } from "vitest";
import {
  dispatch_failure_quip,
  fetch_failure_quip,
  no_match_quip,
  pick_quip,
} from "../src/quips.js";

describe("quips", () => {
  it("fetch_failure_quip returns a non-empty Jinx-flavoured string", () => {
    const q = fetch_failure_quip();
    expect(typeof q).toBe("string");
    expect(q.length).toBeGreaterThan(0);
    expect(q).toMatch(/🐈/);
  });

  it("no_match_quip points the user at #help-rladies", () => {
    const q = no_match_quip();
    expect(q).toMatch(/#help-rladies/);
  });

  it("dispatch_failure_quip mentions retrying or a maintainer", () => {
    const q = dispatch_failure_quip();
    expect(q).toMatch(/try|maintainer/i);
  });

  it("pick_quip eventually returns each entry in the list", () => {
    const list = ["a", "b", "c"];
    const seen = new Set();
    for (let i = 0; i < 500 && seen.size < list.length; i++) {
      seen.add(pick_quip(list));
    }
    expect(seen.size).toBe(list.length);
  });
});
