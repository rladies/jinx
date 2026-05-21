const API = "https://www.googleapis.com/youtube/v3";
const MAX_DESCRIPTION_CHARS = 4000;

export async function gatherYoutubeChannelSource(src) {
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (!apiKey) {
    console.error("YOUTUBE_API_KEY not set — skipping youtube-channel source");
    return [];
  }

  console.log(`Discovering uploads playlist for ${src.channelId}`);
  const uploadsId = await fetchUploadsPlaylistId(src.channelId, apiKey);
  if (!uploadsId) {
    console.error(`  could not resolve uploads playlist for ${src.channelId}`);
    return [];
  }

  const items = await fetchAllPlaylistItems(uploadsId, apiKey);
  console.log(`  ${items.length} videos in uploads playlist`);

  const out = [];
  for (const item of items) {
    const snippet = item.snippet || {};
    const videoId = snippet.resourceId?.videoId;
    if (!videoId) continue;
    const title = snippet.title || "Untitled video";
    if (title === "Private video" || title === "Deleted video") continue;
    const description = (snippet.description || "").slice(0, MAX_DESCRIPTION_CHARS);
    const published = parseDate(snippet.publishedAt);
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    const text = formatVideo(title, snippet.publishedAt, description);
    out.push({
      text,
      heading: "YouTube",
      title,
      repo: src.repo || "rladies/youtube",
      path: `video/${videoId}`,
      url,
      date: published,
      lastmod: published,
      chunk_idx: 0,
    });
  }

  console.log(`  ${out.length} chunks from youtube-channel`);
  return out;
}

function formatVideo(title, publishedAt, description) {
  const lines = [`Title: ${title}`];
  if (publishedAt) lines.push(`Published: ${publishedAt}`);
  if (description) {
    lines.push("");
    lines.push(description.trim());
  }
  return lines.join("\n");
}

async function fetchUploadsPlaylistId(channelId, apiKey) {
  const url = `${API}/channels?part=contentDetails&id=${encodeURIComponent(channelId)}&key=${apiKey}`;
  const json = await fetchJson(url);
  const items = json?.items || [];
  return items[0]?.contentDetails?.relatedPlaylists?.uploads || null;
}

async function fetchAllPlaylistItems(playlistId, apiKey) {
  const all = [];
  let pageToken = "";
  for (;;) {
    const url =
      `${API}/playlistItems?part=snippet&maxResults=50&playlistId=${encodeURIComponent(playlistId)}` +
      `&key=${apiKey}` +
      (pageToken ? `&pageToken=${pageToken}` : "");
    const json = await fetchJson(url);
    if (!json) break;
    for (const item of json.items || []) all.push(item);
    if (!json.nextPageToken) break;
    pageToken = json.nextPageToken;
  }
  return all;
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
    console.error(`  youtube fetch failed ${res.status}: ${await res.text()}`);
    return null;
  }
  return res.json();
}
