// Weekly question-gap digest. Reads the anonymous question log, surfaces the
// gaps worth a human's attention, drafts a *proposed* Guide answer for each top
// gap, and posts the lot to the global-team Slack channel for review.
//
// GUARDRAIL: a draft is only ever a Slack message for a human to verify. Nothing
// here writes to the RAG index or any source repo — the corpus stays
// human-authored. Drafts are AI-suggested and unverified by construction.
import {
  question_log_since,
  question_gaps_rank,
  question_downvoted_rank,
} from "./question-log.js";
import { CHAT_MODEL } from "./rag.js";
import { slack_message_post, slack_channel_id_lookup } from "./slack-api.js";

// no_match / low_confidence are "the Guide may be thin here". coding_declined is
// excluded — declining code questions is working as designed, not a corpus gap.
const CONTENT_GAP_OUTCOMES = new Set(["no_match", "low_confidence"]);
const DEFAULT_DIGEST_CHANNEL = "team-jinx";
const GAP_LIMIT = 10;
const DRAFT_LIMIT = 5;
const DOWNVOTED_LIMIT = 5;

const DRAFT_SYSTEM_PROMPT = `You are helping the RLadies+ global team improve their organiser Guide. You are given a question that Jinx (the RLadies+ assistant) could not answer well.

Draft a SHORT proposed Guide answer (2–4 sentences) for a human to review before publishing. Rules:
- Only state what you are genuinely confident is accurate RLadies+ practice. If you are unsure of specifics (dates, amounts, exact process), say plainly what the team needs to confirm rather than inventing it.
- Write the organisation name as *RLadies+* — one word, trailing plus, no hyphen.
- No preamble, no "here is a draft" — just the proposed answer text.
- Never invent URLs, names, figures, or policies.`;

export function content_gaps(rows, { minCount = 1, limit = GAP_LIMIT } = {}) {
  const gapRows = (rows || []).filter((r) =>
    CONTENT_GAP_OUTCOMES.has(r.outcome),
  );
  return question_gaps_rank(gapRows, limit).filter((g) => g.count >= minCount);
}

export function coding_declined_count(rows) {
  return (rows || []).filter((r) => r.outcome === "coding_declined").length;
}

export async function draft_guide_snippet(env, question) {
  try {
    const result = await env.AI.run(CHAT_MODEL, {
      messages: [
        { role: "system", content: DRAFT_SYSTEM_PROMPT },
        {
          role: "user",
          content: `Question Jinx could not answer well:\n"${question}"\n\nDraft a proposed Guide answer.`,
        },
      ],
      max_tokens: 250,
    });
    return (result?.response || "").trim() || null;
  } catch (e) {
    console.warn("draft_guide_snippet failed:", e.message);
    return null;
  }
}

function since_day(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

function truncate(text, max = 140) {
  const s = (text || "").replace(/\s+/g, " ").trim();
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}

export function format_digest({
  days,
  total,
  gaps,
  drafts,
  downvoted,
  codingCount,
}) {
  const lines = [
    `🔮 *Jinx weekly question review — last ${days} day${days === 1 ? "" : "s"}* (${total} question${total === 1 ? "" : "s"} logged)`,
  ];

  if (drafts.length) {
    lines.push(
      "",
      "*Gaps to close* — the Guide may be thin here. Each carries a *draft* answer to review:",
    );
    for (const d of drafts) {
      const times = d.count > 1 ? ` _(asked ×${d.count})_` : "";
      lines.push("", `• *${truncate(d.question)}*${times}`);
      lines.push(
        d.draft
          ? `    ◦ _draft:_ ${d.draft}`
          : "    ◦ _(couldn't draft one — needs the team to write this)_",
      );
    }
  }

  const undrafted = gaps.slice(drafts.length);
  if (undrafted.length) {
    lines.push("", "*More gaps* (no draft — pick these up next):");
    for (const g of undrafted) {
      const times = g.count > 1 ? ` _(×${g.count})_` : "";
      lines.push(`• ${truncate(g.question)}${times}`);
    }
  }

  if (!gaps.length) {
    lines.push("", "*Gaps to close:* none this week — I answered everything asked. 😺");
  }

  if (downvoted.length) {
    lines.push("", "*Answers folks 👎'd* (may be wrong, stale, or mis-retrieved):");
    for (const d of downvoted) {
      lines.push(`• ${truncate(d.question)} — 👎 ${d.down} / 👍 ${d.up}`);
    }
  }

  if (codingCount > 0) {
    lines.push(
      "",
      `_FYI: I declined ${codingCount} coding question${codingCount === 1 ? "" : "s"} → pointed to *#help-r* (working as designed, not a Guide gap)._`,
    );
  }

  lines.push(
    "",
    "🐈‍⬛ _Drafts are AI-suggested and *unverified* — please confirm before adding anything to the Guide._",
  );
  return lines.join("\n");
}

export async function question_digest_build(env, { days = 7 } = {}) {
  if (!env.QUESTION_LOG) return null;
  const rows = await question_log_since(env, since_day(days));
  if (!rows.length) return null;

  const gaps = content_gaps(rows, { minCount: 1 });
  const downvoted = question_downvoted_rank(rows, DOWNVOTED_LIMIT);
  const codingCount = coding_declined_count(rows);

  const drafts = [];
  for (const g of gaps.slice(0, DRAFT_LIMIT)) {
    drafts.push({ ...g, draft: await draft_guide_snippet(env, g.question) });
  }

  return format_digest({
    days,
    total: rows.length,
    gaps,
    drafts,
    downvoted,
    codingCount,
  });
}

export async function question_digest_post(env, { days = 7 } = {}) {
  const teamId = env.SLACK_ORGANIZER_TEAM_ID;
  if (!teamId) {
    console.warn("digest: SLACK_ORGANIZER_TEAM_ID not set; skipping");
    return false;
  }
  const text = await question_digest_build(env, { days });
  if (!text) return false;

  const channelName = env.SLACK_DIGEST_CHANNEL || DEFAULT_DIGEST_CHANNEL;
  const channelId = await slack_channel_id_lookup(env, teamId, channelName).catch(
    () => null,
  );
  if (!channelId) {
    console.warn(`digest: channel #${channelName} not found; skipping`);
    return false;
  }

  await slack_message_post(env, teamId, { channel: channelId, text });
  return true;
}
