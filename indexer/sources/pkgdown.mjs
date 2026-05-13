import { chunkMarkdown } from "../chunk.mjs";

export async function gatherPkgdownLlmsSource(src) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("GITHUB_TOKEN not set — skipping pkgdown-llms source");
    return [];
  }

  console.log(`Discovering R packages in ${src.org}`);
  const candidates = await listOrgRRepos(src.org, token);
  console.log(`  ${candidates.length} R-language repos, checking for DESCRIPTION`);
  const repos = [];
  for (const repo of candidates) {
    if (await hasDescription(repo.full_name, token)) {
      repos.push(repo);
    }
  }
  console.log(`  ${repos.length} repos with a root DESCRIPTION`);

  const out = [];
  for (const repo of repos) {
    const baseUrl = `https://rladies.github.io/${repo.name}`;
    const llmsUrl = `${baseUrl}/llms.txt`;
    const text = await fetchText(llmsUrl);
    if (!text) {
      console.log(`  ${repo.full_name}: no llms.txt`);
      continue;
    }
    const meta = {
      repo: repo.full_name,
      path: "llms.txt",
      url: baseUrl,
      fallbackTitle: `${repo.name} (R package)`,
    };
    const chunks = chunkMarkdown(text, meta);
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
    console.log(`  ${repo.full_name}: ${chunks.length} chunks`);
  }
  console.log(`  ${out.length} chunks from pkgdown source`);
  return out;
}

async function listOrgRRepos(org, token) {
  const out = [];
  let url = `https://api.github.com/orgs/${org}/repos?per_page=100`;
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
      throw new Error(`Failed to list repos: ${res.status} ${await res.text()}`);
    }
    for (const r of await res.json()) {
      if (r.archived || r.disabled) continue;
      if (r.language !== "R") continue;
      out.push(r);
    }
    url = nextLink(res.headers.get("link"));
  }
  return out;
}

async function hasDescription(fullName, token) {
  const res = await fetch(
    `https://api.github.com/repos/${fullName}/contents/DESCRIPTION`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "rladies-jinx",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    }
  );
  if (res.status === 404) return false;
  if (!res.ok) {
    console.warn(`  HEAD ${fullName}/DESCRIPTION -> ${res.status}`);
    return false;
  }
  return true;
}

function nextLink(linkHeader) {
  if (!linkHeader) return null;
  for (const part of linkHeader.split(",")) {
    const m = part.match(/<([^>]+)>;\s*rel="next"/);
    if (m) return m[1];
  }
  return null;
}

async function fetchText(url) {
  const res = await fetch(url, {
    redirect: "follow",
    headers: { "User-Agent": "rladies-jinx" },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    console.warn(`  GET ${url} -> ${res.status}`);
    return null;
  }
  return await res.text();
}
