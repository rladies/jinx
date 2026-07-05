// Anonymous question-improvement log. Records *what* was asked and how well
// Jinx answered — never *who* asked. No Slack user id, channel name, or thread
// timestamp is stored; identifiers are dropped at the capture point, not
// scrubbed afterwards. The log exists so maintainers can see where the corpus
// is thin (questions Jinx couldn't answer) and which answers earned a 👎.

const QUESTION_MAX_CHARS = 500;
const ANSWER_LINK_TTL_SECONDS = 7 * 24 * 60 * 60;
const RETENTION_DAYS = 180;

const GAP_OUTCOMES = new Set(["no_match", "coding_declined", "low_confidence"]);

const UP_REACTIONS = new Set([
  "+1",
  "thumbsup",
  "heart",
  "heart_eyes",
  "tada",
  "raised_hands",
  "star-struck",
  "100",
]);
const DOWN_REACTIONS = new Set([
  "-1",
  "thumbsdown",
  "disappointed",
  "confused",
]);

export function reaction_direction(reaction) {
  const r = (reaction || "").split("::")[0];
  if (UP_REACTIONS.has(r)) return "up";
  if (DOWN_REACTIONS.has(r)) return "down";
  return null;
}

function answer_link_key(teamId, channel, ts) {
  return `answer_link:${teamId}:${channel}:${ts}`;
}

function question_truncate(question) {
  const s = (question || "").trim();
  return s.length > QUESTION_MAX_CHARS ? s.slice(0, QUESTION_MAX_CHARS) : s;
}

// Insert one anonymous row and, when the answer landed as a single Slack
// message, remember which question it answers so a later 👍/👎 reaction can
// find it. The link lives in KV with a short TTL — long enough for someone to
// react, short enough that it never becomes a durable message index.
export async function question_capture(
  env,
  { teamId, channel, answerTs, question, outcome, top_score, sources },
) {
  if (!env.QUESTION_LOG) return null;
  const text = question_truncate(question);
  if (!text) return null;

  const day = new Date().toISOString().slice(0, 10);
  let id = null;
  try {
    const res = await env.QUESTION_LOG.prepare(
      "INSERT INTO questions (day, question, outcome, top_score, sources) VALUES (?, ?, ?, ?, ?)",
    )
      .bind(day, text, outcome, top_score ?? null, sources ?? null)
      .run();
    id = res?.meta?.last_row_id ?? null;
  } catch (e) {
    console.error("question_log insert failed:", e.message);
    return null;
  }

  if (id && answerTs && channel && env.SLACK_TOKENS) {
    await env.SLACK_TOKENS.put(
      answer_link_key(teamId, channel, answerTs),
      String(id),
      { expirationTtl: ANSWER_LINK_TTL_SECONDS },
    ).catch((e) => console.warn("answer_link write failed:", e.message));
  }
  return id;
}

// Apply a 👍/👎 to the question a reaction's target message answered. Reactions
// on anything Jinx posted that is not a linked answer (welcomes, prompts, long
// answers uploaded as files) fall through untouched. The reacting user is never
// read here — only the item they reacted to.
export async function question_vote_apply(env, { teamId, item, reaction }) {
  if (!env.QUESTION_LOG || !env.SLACK_TOKENS) return false;
  if (item?.type !== "message" || !item.channel || !item.ts) return false;

  const dir = reaction_direction(reaction);
  if (!dir) return false;

  const idRaw = await env.SLACK_TOKENS.get(
    answer_link_key(teamId, item.channel, item.ts),
  ).catch(() => null);
  if (!idRaw) return false;
  const id = Number(idRaw);
  if (!Number.isInteger(id)) return false;

  const column = dir === "up" ? "up" : "down";
  try {
    await env.QUESTION_LOG.prepare(
      `UPDATE questions SET ${column} = ${column} + 1 WHERE id = ?`,
    )
      .bind(id)
      .run();
  } catch (e) {
    console.error("question_log vote failed:", e.message);
    return false;
  }
  return true;
}

export async function question_log_since(env, sinceDay) {
  if (!env.QUESTION_LOG) return [];
  const res = await env.QUESTION_LOG.prepare(
    "SELECT id, day, question, outcome, top_score, sources, up, down FROM questions WHERE day >= ? ORDER BY day DESC",
  )
    .bind(sinceDay)
    .all()
    .catch((e) => {
      console.error("question_log query failed:", e.message);
      return null;
    });
  return res?.results || [];
}

function normalize_question(question) {
  return (question || "").toLowerCase().replace(/\s+/g, " ").trim();
}

// The gap list is the corpus to-do list: the questions Jinx declined or came up
// empty on, plus the ones she answered with thin retrieval. Near-duplicates are
// folded together so a popular unanswered question rises to the top.
export function question_gaps_rank(rows, limit = 10) {
  const counts = new Map();
  for (const r of rows || []) {
    if (!GAP_OUTCOMES.has(r.outcome)) continue;
    const key = normalize_question(r.question);
    if (!key) continue;
    const entry = counts.get(key) || {
      question: r.question,
      outcome: r.outcome,
      count: 0,
    };
    entry.count += 1;
    counts.set(key, entry);
  }
  return [...counts.values()]
    .sort((a, b) => b.count - a.count)
    .slice(0, limit);
}

export function question_downvoted_rank(rows, limit = 10) {
  return (rows || [])
    .filter((r) => (r.down || 0) > (r.up || 0))
    .sort((a, b) => b.down - b.up - (a.down - a.up))
    .slice(0, limit);
}

// D1 rows do not expire on their own the way the KV reaction tallies do, so the
// scheduled handler calls this daily to honour the 180-day retention promise in
// PRIVACY.md. Deletes whole rows past the window — question text and vote counts
// alike.
export async function question_log_purge(env, retentionDays = RETENTION_DAYS) {
  if (!env.QUESTION_LOG) return 0;
  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
  try {
    const res = await env.QUESTION_LOG.prepare(
      "DELETE FROM questions WHERE day < ?",
    )
      .bind(cutoff)
      .run();
    return res?.meta?.changes ?? 0;
  } catch (e) {
    console.error("question_log purge failed:", e.message);
    return 0;
  }
}
