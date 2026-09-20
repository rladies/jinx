-- Anonymous question-improvement log. One row per question asked of Jinx.
-- No Slack user id, channel, or thread timestamp is ever stored here.
CREATE TABLE IF NOT EXISTS questions (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  day       TEXT NOT NULL,               -- 'YYYY-MM-DD' bucket, no finer time
  question  TEXT NOT NULL,               -- truncated to 500 chars at capture
  outcome   TEXT NOT NULL,               -- answered | no_match | coding_declined | low_confidence
  top_score REAL,                        -- best reranked retrieval score; NULL when nothing retrieved
  sources   TEXT,                        -- source_types retrieved, comma-joined
  up        INTEGER NOT NULL DEFAULT 0,  -- 👍 reactions on the answer
  down      INTEGER NOT NULL DEFAULT 0   -- 👎 reactions on the answer
);

CREATE INDEX IF NOT EXISTS idx_questions_day ON questions (day);
CREATE INDEX IF NOT EXISTS idx_questions_outcome ON questions (outcome);
