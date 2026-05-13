#!/usr/bin/env node
import { gatherHugoSiteSource } from "../sources/hugo-site.mjs";

const SITES = [
  {
    label: "rladies.github.io",
    config: {
      type: "hugo-site",
      source_type: "site",
      repo: "rladies/rladies.github.io",
      publicDir:
        process.env.RLADIES_SITE_PUBLIC ||
        "/Users/athanasm/workspace/rladies/rladies.github.io/public",
      baseUrl: "https://rladies.org",
      titleSuffix: " - RLadies+ Global",
      languageRoots: { english: null, others: ["es", "fr", "pt"] },
    },
    samples: [/\/about-us\/coc\/$/, /\/about-us\/our-story\/$/, /\/$/],
  },
  {
    label: "rladiesguide",
    config: {
      type: "hugo-site",
      source_type: "guide",
      repo: "rladies/rladiesguide",
      publicDir:
        process.env.RLADIESGUIDE_PUBLIC ||
        "/Users/athanasm/workspace/rladies/rladiesguide/public",
      baseUrl: "https://guide.rladies.org",
      titleSuffix: " :: R-Ladies organizational guidance",
      languageRoots: { english: "en", others: ["es"] },
    },
    samples: [
      /\/global-team\/code-of-conduct\/$/,
      /\/organize\/new-chapter\/$/,
      /\/organizers\/online-presence\/website\/$/,
      /\/en\/$/,
    ],
  },
];

for (const site of SITES) {
  console.log(`\n=== ${site.label} ===`);
  const chunks = await gatherHugoSiteSource(site.config);
  console.log(`  total chunks: ${chunks.length}`);

  for (const pat of site.samples) {
    const hit = chunks.find((c) => pat.test(c.url));
    if (!hit) {
      console.log(`\n  sample for ${pat}: (none matched)`);
      continue;
    }
    console.log(`\n  sample: ${hit.url}`);
    console.log(`    title:   ${hit.title}`);
    console.log(`    heading: ${hit.heading || "(top of page)"}`);
    console.log(`    text head:`);
    console.log(`      ${hit.text.replace(/\s+/g, " ").slice(0, 320)}…`);
  }
}
