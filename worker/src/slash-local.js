import {
  slack_bookmarks_add,
  slack_bookmarks_list,
  slack_conversations_info,
  slack_conversations_join,
  slack_conversations_open,
  slack_message_post,
  slack_reminders_add,
} from "./slack-api.js";
import {
  question_log_since,
  question_gaps_rank,
  question_downvoted_rank,
} from "./question-log.js";
import { slack_global_team_authorize } from "./authorize.js";

const BOOKMARKS_CONFIG_URL =
  "https://raw.githubusercontent.com/rladies/jinx/main/inst/config/bookmarks.json";

const CHAPTER_BOOKMARKS_FALLBACK = [
  { title: "RLadies+ Guide", link: "https://guide.rladies.org", emoji: ":sparkles:" },
  { title: "Code of Conduct", link: "https://rladies.org/coc/", emoji: ":scales:" },
  { title: "RLadies+ Events", link: "https://rladies.org/events/", emoji: ":calendar:" },
  { title: "Jinx (GitHub)", link: "https://github.com/rladies/jinx", emoji: ":crystal_ball:" },
];

async function bookmarks_config_fetch() {
  try {
    const res = await fetch(BOOKMARKS_CONFIG_URL, {
      headers: { "User-Agent": "rladies-jinx" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const cfg = await res.json();
    const list = Array.isArray(cfg?.bookmarks) ? cfg.bookmarks : null;
    if (!list?.length) throw new Error("empty bookmarks array");
    return list.filter((b) => b?.title && b?.link);
  } catch (e) {
    console.warn("Bookmarks config fetch failed; using fallback:", e.message);
    return CHAPTER_BOOKMARKS_FALLBACK;
  }
}

const LOCAL_COMMANDS = new Set([
  "setup-channel",
  "remind-me",
  "pair",
  "feedback",
  "questions",
]);

export function slash_is_local(command) {
  const verb = command.split(/\s+/)[0];
  return LOCAL_COMMANDS.has(verb);
}

// Commands that expose the community's questions and answer feedback. Gated to
// the global team — the question log is anonymous, but it is still the org's
// operational data, not for every workspace member to browse. Authorization
// reuses the shared Airtable member directory (see slack_global_team_authorize).
const GLOBAL_TEAM_COMMANDS = new Set(["questions", "feedback"]);

export function command_requires_global_team(command) {
  return GLOBAL_TEAM_COMMANDS.has(command.split(/\s+/)[0]);
}

export async function slash_local_handle(env, teamId, command, params, responseUrl) {
  const [verb, ...rest] = command.split(/\s+/);
  const args = rest.join(" ").trim();
  const channelId = params.get("channel_id") || "";
  const channelName = params.get("channel_name") || "";
  const userId = params.get("user_id") || "";

  if (command_requires_global_team(command)) {
    const authz = await slack_global_team_authorize(env, { teamId, userId });
    if (!authz.ok) {
      await slash_respond(responseUrl, authz.message);
      return;
    }
  }

  try {
    switch (verb) {
      case "setup-channel":
        return await slash_setup_channel(env, teamId, channelId, channelName, responseUrl);
      case "remind-me":
        return await slash_remind_me(env, teamId, userId, args, responseUrl);
      case "pair":
        return await slash_pair(env, teamId, userId, args, responseUrl);
      case "feedback":
        return await slash_feedback(env, teamId, args, responseUrl);
      case "questions":
        return await slash_questions(env, args, responseUrl);
    }
  } catch (err) {
    console.error(`Local command "${verb}" failed:`, err);
    await slash_respond(responseUrl, `😿 ${verb} didn't quite land — paws-up: ${err.message}`);
  }
}

async function slash_setup_channel(env, teamId, channelId, channelName, responseUrl) {
  if (!channelId) {
    await slash_respond(responseUrl, "Pop into the channel you want to set up and run this again — I can only tidy the room I'm standing in.");
    return;
  }

  let info;
  try {
    info = await slack_conversations_info(env, teamId, channelId);
  } catch (e) {
    await slash_respond(responseUrl, `I can't quite see into <#${channelId}> from here: ${e.message}`);
    return;
  }

  const isPrivate = info?.channel?.is_private;
  const isMember = info?.channel?.is_member;

  if (!isMember && !isPrivate) {
    await slack_conversations_join(env, teamId, channelId).catch((e) =>
      console.warn("conversations.join failed:", e.message)
    );
  }
  if (!isMember && isPrivate) {
    await slash_respond(
      responseUrl,
      `🐈‍⬛ I'm not in <#${channelId}> yet (and I can't let myself in — no thumbs!). Invite me first, since it's a private channel, then run \`/jinx setup-channel\` again.`
    );
    return;
  }

  const existing = await slack_bookmarks_list(env, teamId, channelId).catch(() => ({}));
  const existingLinks = new Set(
    (existing?.bookmarks || []).map((b) => (b.link || "").toLowerCase())
  );

  const bookmarks = await bookmarks_config_fetch();
  const added = [];
  const skipped = [];
  for (const bm of bookmarks) {
    if (existingLinks.has(bm.link.toLowerCase())) {
      skipped.push(bm.title);
      continue;
    }
    try {
      await slack_bookmarks_add(env, teamId, {
        channelId,
        title: bm.title,
        link: bm.link,
        emoji: bm.emoji,
      });
      added.push(bm.title);
    } catch (e) {
      console.warn(`bookmark "${bm.title}" failed:`, e.message);
    }
  }

  const lines = [`🔮 Set up *#${channelName || channelId}* with RLadies+ resources.`];
  if (added.length) lines.push(`*Added:* ${added.join(", ")}`);
  if (skipped.length) lines.push(`*Already there:* ${skipped.join(", ")}`);
  await slash_respond(responseUrl, lines.join("\n"));
}

async function slash_remind_me(env, teamId, userId, args, responseUrl) {
  if (!args) {
    await slash_respond(
      responseUrl,
      "Usage: `/jinx remind-me <when> | <what>` — for example: `/jinx remind-me in 30 minutes | check the chapter onboarding queue`"
    );
    return;
  }
  const [when, ...rest] = args.split("|").map((s) => s.trim());
  const what = rest.join("|").trim();
  if (!when || !what) {
    await slash_respond(
      responseUrl,
      "Pop a `|` between the time and the reminder so I can tell them apart. Example: `/jinx remind-me in 30 minutes | check the chapter onboarding queue`"
    );
    return;
  }

  await slack_reminders_add(env, teamId, { text: what, time: when, user: userId });
  await slash_respond(responseUrl, `⏰ Tied a string round my paw for <@${userId}>: *${what}* (${when})`);
}

async function slash_pair(env, teamId, callerId, args, responseUrl) {
  const { userIds, message } = parse_pair_args(args);

  if (userIds.length === 0) {
    await slash_respond(
      responseUrl,
      "Usage: `/jinx pair @alice @bob <optional message>` — opens a group DM with you and the people you mention.\n" +
        "_If `@`-mentions come through as plain text, enable *Escape channels, users, and links* on the slash command in the Slack app config._"
    );
    return;
  }

  const others = userIds.filter((id) => id !== callerId);
  if (others.length === 0) {
    await slash_respond(responseUrl, "Tag at least one other human — I'm a cat, not a conversation.");
    return;
  }
  if (others.length > 7) {
    await slash_respond(
      responseUrl,
      `Slack group DMs cap at 8 people including you, so I can pair you with at most 7 others (you mentioned ${others.length}). Even my whiskers can only stretch so far.`
    );
    return;
  }

  const users = [callerId, ...others].join(",");
  const res = await slack_conversations_open(env, teamId, { users });
  const channelId = res?.channel?.id;
  if (!channelId) {
    await slash_respond(responseUrl, "😿 I fumbled the group DM open — try again in a moment?");
    return;
  }

  const mentionList = others.map((id) => `<@${id}>`).join(", ");
  const intro = `🔮 <@${callerId}> opened this group DM with ${mentionList}` +
    (message ? `:\n\n${message}` : ".");
  await slack_message_post(env, teamId, { channel: channelId, text: intro });
  await slash_respond(responseUrl, `✉️ Nudged open a group DM with ${mentionList}.`);
}

function parse_pair_args(args) {
  const userIds = [];
  const remaining = (args || "").replace(/<@([UW][A-Z0-9]+)(?:\|[^>]+)?>/g, (_, id) => {
    userIds.push(id);
    return "";
  });
  const message = remaining.replace(/\s+/g, " ").trim();
  return { userIds: Array.from(new Set(userIds)), message };
}

async function slash_feedback(env, teamId, args, responseUrl) {
  if (!env.SLACK_TOKENS) {
    await slash_respond(responseUrl, "🐈‍⬛ My feedback log isn't set up yet — nothing to peek at.");
    return;
  }

  const days = Math.max(1, Math.min(30, parseInt((args || "").trim(), 10) || 7));
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);

  const prefix = `reaction_log:${teamId}:`;
  const totals = new Map();
  let cursor;
  let keysScanned = 0;
  do {
    const page = await env.SLACK_TOKENS.list({ prefix, cursor });
    for (const k of page.keys) {
      const parts = k.name.split(":");
      const day = parts[2];
      const emoji = parts.slice(3).join(":");
      if (!day || !emoji || day < since) continue;
      keysScanned++;
      const entry = await env.SLACK_TOKENS.get(k.name, "json").catch(() => null);
      const count = entry?.count || 0;
      totals.set(emoji, (totals.get(emoji) || 0) + count);
    }
    cursor = page.list_complete ? null : page.cursor;
  } while (cursor);

  if (totals.size === 0) {
    await slash_respond(
      responseUrl,
      `📊 No reactions on my answers in the last ${days} day${days === 1 ? "" : "s"} — either I'm doing great or no one's looking. 🐈‍⬛ Once folks react with 👍 / 👎 / ❤️, the counts will land here.`
    );
    return;
  }

  const sorted = [...totals.entries()].sort((a, b) => b[1] - a[1]);
  const lines = [
    `📊 *Jinx feedback — last ${days} day${days === 1 ? "" : "s"}* (${keysScanned} entr${keysScanned === 1 ? "y" : "ies"}):`,
    ...sorted.map(([emoji, n]) => `:${emoji}:  ${n}`),
  ];
  await slash_respond(responseUrl, lines.join("\n"));
}

const GAP_LABELS = {
  no_match: "came up empty",
  coding_declined: "coding — declined",
  low_confidence: "thin retrieval",
};

async function slash_questions(env, args, responseUrl) {
  if (!env.QUESTION_LOG) {
    await slash_respond(
      responseUrl,
      "🐈‍⬛ My question log isn't set up yet — nothing to peek at.",
    );
    return;
  }

  const days = Math.max(1, Math.min(90, parseInt((args || "").trim(), 10) || 30));
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);

  const rows = await question_log_since(env, since);
  if (rows.length === 0) {
    await slash_respond(
      responseUrl,
      `🐈‍⬛ No questions logged in the last ${days} day${days === 1 ? "" : "s"} — quiet whiskers.`,
    );
    return;
  }

  const gaps = question_gaps_rank(rows, 10);
  const downvoted = question_downvoted_rank(rows, 5);

  const lines = [
    `🔮 *What folks asked — last ${days} day${days === 1 ? "" : "s"}* (${rows.length} question${rows.length === 1 ? "" : "s"} logged):`,
  ];

  if (gaps.length) {
    lines.push("", "*Gaps to close* (couldn't answer well):");
    for (const g of gaps) {
      const times = g.count > 1 ? ` _(×${g.count})_` : "";
      lines.push(
        `• ${quote_question(g.question)} — _${GAP_LABELS[g.outcome] || g.outcome}_${times}`,
      );
    }
  } else {
    lines.push("", "*Gaps to close:* none — I answered everything asked. 😺");
  }

  if (downvoted.length) {
    lines.push("", "*Answers folks 👎'd:*");
    for (const d of downvoted) {
      lines.push(`• ${quote_question(d.question)} — 👎 ${d.down} / 👍 ${d.up}`);
    }
  }

  await slash_respond(responseUrl, lines.join("\n"));
}

function quote_question(question) {
  const s = (question || "").replace(/\s+/g, " ").trim();
  return s.length > 120 ? `${s.slice(0, 117)}…` : s;
}

async function slash_respond(responseUrl, text) {
  if (!responseUrl) return;
  await fetch(responseUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ response_type: "ephemeral", text }),
  }).catch((e) => console.error("response_url post failed:", e));
}
