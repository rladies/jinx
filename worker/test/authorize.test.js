import { describe, it, expect, vi, afterEach } from "vitest";
import { slack_is_organizer_workspace } from "../src/authorize.js";

afterEach(() => {
  vi.restoreAllMocks();
});

const ORG_ENV = { SLACK_ORGANIZER_TEAM_ID: "T_ORG" };

describe("slack_is_organizer_workspace", () => {
  it("is true only for the configured organiser team id", () => {
    expect(slack_is_organizer_workspace(ORG_ENV, "T_ORG")).toBe(true);
    expect(slack_is_organizer_workspace(ORG_ENV, "T_COMMUNITY")).toBe(false);
  });

  it("is false when no organiser team id is configured", () => {
    expect(slack_is_organizer_workspace({}, "T_ORG")).toBe(false);
  });
});
