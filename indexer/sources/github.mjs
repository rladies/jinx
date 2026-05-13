import { chunkMarkdown } from "../chunk.mjs";

export async function gatherGithubOrgSource(src) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("GITHUB_TOKEN not set — skipping github source");
    return [];
  }

  console.log(`Fetching org data for ${src.org}`);

  const teams = await getAllPages(`/orgs/${src.org}/teams`, token);
  console.log(`  ${teams.length} teams`);

  const repos = await getAllPages(`/orgs/${src.org}/repos`, token);
  const liveRepos = repos.filter((r) => !r.archived && !r.disabled);
  console.log(`  ${repos.length} repos (${liveRepos.length} live)`);

  const out = [];

  for (const team of teams) {
    if (team.privacy && team.privacy !== "closed") continue;
    out.push({
      text: renderTeamText(team),
      heading: "",
      title: `Team: ${team.name}`,
      repo: `${src.org}/.teams`,
      path: team.slug,
      url:
        team.html_url ||
        `https://github.com/orgs/${src.org}/teams/${team.slug}`,
      chunk_idx: 0,
    });
  }

  for (const repo of liveRepos) {
    out.push({
      text: renderRepoMetaText(repo),
      heading: "",
      title: repo.full_name,
      repo: repo.full_name,
      path: "_meta",
      url: repo.html_url,
      chunk_idx: 0,
    });

    const readme = await fetchReadme(repo.full_name, token);
    if (readme && readme.trim()) {
      const meta = {
        repo: repo.full_name,
        path: "README.md",
        url: repo.html_url,
        fallbackTitle: `${repo.full_name} README`,
      };
      const readmeChunks = chunkMarkdown(readme, meta);
      for (let i = 0; i < readmeChunks.length; i++) {
        out.push({ ...readmeChunks[i], chunk_idx: i });
      }
    }
  }

  console.log(`  ${out.length} chunks from github source`);
  return out;
}

function renderTeamText(team) {
  const lines = [
    `Team name: ${team.name}`,
    `Slug: ${team.slug}`,
    `Description: ${team.description || "(no description)"}`,
  ];
  if (team.parent) lines.push(`Parent team: ${team.parent.name}`);
  if (team.privacy) lines.push(`Visibility: ${team.privacy}`);
  return lines.join("\n");
}

function renderRepoMetaText(repo) {
  const lines = [
    `Repository: ${repo.full_name}`,
    `Description: ${repo.description || "(no description)"}`,
    `Primary language: ${repo.language || "n/a"}`,
    `Topics: ${(repo.topics || []).join(", ") || "(none)"}`,
    `License: ${repo.license?.spdx_id || "n/a"}`,
    `Homepage: ${repo.homepage || repo.html_url}`,
    `Visibility: ${repo.private ? "private" : "public"}`,
  ];
  return lines.join("\n");
}

async function getAllPages(path, token) {
  const out = [];
  const sep = path.includes("?") ? "&" : "?";
  let url = `https://api.github.com${path}${sep}per_page=100`;
  while (url) {
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });
    if (!res.ok) {
      throw new Error(`GET ${url} -> ${res.status} ${await res.text()}`);
    }
    out.push(...(await res.json()));
    url = nextLink(res.headers.get("link"));
  }
  return out;
}

function nextLink(linkHeader) {
  if (!linkHeader) return null;
  for (const part of linkHeader.split(",")) {
    const m = part.match(/<([^>]+)>;\s*rel="next"/);
    if (m) return m[1];
  }
  return null;
}

async function fetchReadme(fullName, token) {
  const res = await fetch(`https://api.github.com/repos/${fullName}/readme`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github.raw",
      "User-Agent": "rladies-jinx",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    console.error(`README fetch failed for ${fullName}: ${res.status}`);
    return null;
  }
  return await res.text();
}
