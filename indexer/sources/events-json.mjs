const PAST_WINDOW_SECONDS = 365 * 24 * 60 * 60;
const MIN_CHARS = 80;

export async function gatherEventsJsonSource(src) {
  const json = await fetchJson(src.url);
  if (!json || !Array.isArray(json)) {
    console.error(`  events-json: no array at ${src.url}`);
    return [];
  }

  const now = Math.floor(Date.now() / 1000);
  const cutoff = now - PAST_WINDOW_SECONDS;
  const kept = [];
  let pastDropped = 0;
  let cancelledDropped = 0;
  let activeCount = 0;

  for (const ev of json) {
    if (ev.status === "cancelled") {
      cancelledDropped++;
      continue;
    }
    const ts = parseDate(ev.datetime_utc || ev.datetime);
    if (ev.status === "past" && ts && ts < cutoff) {
      pastDropped++;
      continue;
    }
    if (ev.status === "active") activeCount++;
    kept.push({ ev, ts });
  }

  const out = [];
  for (const { ev, ts } of kept) {
    const text = formatEvent(ev);
    if (text.length < MIN_CHARS) continue;
    const id = String(ev.id || ev.link || `${ev.group_urlname}-${ts}`);
    out.push({
      text,
      heading: ev.group_name || "",
      title: ev.title || "Untitled event",
      repo: src.repo,
      path: `event/${id}`,
      url: ev.link,
      date: ts || 0,
      lastmod: ts || 0,
      chunk_idx: 0,
    });
  }

  console.log(
    `  ${out.length} chunks from events.json (active ${activeCount}, dropped ${pastDropped} past>${PAST_WINDOW_SECONDS / 86400}d, ${cancelledDropped} cancelled)`
  );
  return out;
}

function formatEvent(ev) {
  const lines = [];
  if (ev.title) lines.push(`Title: ${ev.title}`);
  if (ev.group_name) lines.push(`Chapter: ${ev.group_name}`);
  const when = ev.datetime || ev.datetime_utc;
  if (when) lines.push(`When: ${when}`);
  if (ev.status) lines.push(`Status: ${ev.status === "active" ? "upcoming" : "past"}`);
  const where = formatVenue(ev);
  if (where) lines.push(`Where: ${where}`);
  if (ev.going != null) lines.push(`Attendance: ${ev.going}`);
  if (ev.description) {
    lines.push("");
    lines.push(stripHtml(ev.description).trim());
  }
  return lines.join("\n");
}

function formatVenue(ev) {
  const parts = [];
  if (ev.venue_name) parts.push(ev.venue_name);
  if (ev.venue_address) parts.push(ev.venue_address);
  if (ev.venue_city) parts.push(ev.venue_city);
  if (ev.venue_country) parts.push(ev.venue_country);
  if (parts.length === 0 && ev.location) return ev.location;
  return parts.join(", ");
}

function stripHtml(s) {
  return String(s)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function parseDate(raw) {
  if (!raw) return 0;
  const ms = Date.parse(raw);
  if (Number.isNaN(ms)) return 0;
  return Math.floor(ms / 1000);
}

async function fetchJson(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": "rladies-jinx-indexer" },
  });
  if (!res.ok) {
    console.error(`  events-json fetch ${url} -> ${res.status}`);
    return null;
  }
  return res.json();
}
