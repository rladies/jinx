import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { chunkMarkdown } from "../chunk.mjs";

export async function gatherGithubFilesSource(src) {
  const out = [];
  for (const entry of src.files) {
    const absPath = join(src.root, entry.path);
    let md;
    try {
      md = await readFile(absPath, "utf-8");
    } catch (e) {
      console.warn(`  ${entry.path}: ${e.message}`);
      continue;
    }
    const meta = {
      repo: src.repo,
      path: entry.path,
      url: entry.url,
      fallbackTitle: entry.title || entry.path,
    };
    const chunks = chunkMarkdown(md, meta);
    for (let i = 0; i < chunks.length; i++) {
      out.push({ ...chunks[i], chunk_idx: i });
    }
  }
  console.log(`  ${out.length} chunks from ${src.repo} (github-files)`);
  return out;
}
