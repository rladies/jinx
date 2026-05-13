import { chunkMarkdown } from "../chunk.mjs";

export async function gatherGithubRemoteFilesSource(src) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("GITHUB_TOKEN not set — skipping github-remote-files source");
    return [];
  }

  const out = [];
  for (const entry of src.files) {
    const md = await fetchRawFile(src.repo, entry.path, token);
    if (md === null) {
      console.warn(`  ${src.repo}/${entry.path}: not found`);
      continue;
    }
    const meta = {
      repo: src.repo,
      path: entry.path,
      url: entry.url,
      fallbackTitle: entry.title || `${src.repo}/${entry.path}`,
    };
    const chunks = chunkMarkdown(md, meta);
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
  }
  console.log(`  ${out.length} chunks from ${src.repo} (github-remote-files)`);
  return out;
}

async function fetchRawFile(repo, path, token) {
  const res = await fetch(
    `https://api.github.com/repos/${repo}/contents/${encodeURIComponent(path).replace(/%2F/g, "/")}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github.raw",
        "User-Agent": "rladies-jinx",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    }
  );
  if (res.status === 404) return null;
  if (!res.ok) {
    console.error(`  ${repo}/${path} fetch failed: ${res.status}`);
    return null;
  }
  return await res.text();
}
