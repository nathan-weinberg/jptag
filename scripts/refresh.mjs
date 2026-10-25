// Refresh all project sources, then write a Markdown review report.
//
// Usage: node scripts/refresh.mjs [--report path/to/report.md]
// Each source is isolated: if one fails, its previous data file is kept and the others still run.
import { existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, normUrl, readYaml, writeGenerated } from './lib.mjs';
import { fetchMbta } from './fetch-mbta.mjs';
import { fetchDcr } from './fetch-dcr.mjs';
import { fetchBoston } from './fetch-boston.mjs';

const SOURCES = [
  { name: 'mbta', label: 'MBTA', fetch: fetchMbta, file: '_data/projects_auto/mbta.yml' },
  { name: 'dcr', label: 'DCR (mass.gov)', fetch: fetchDcr, file: '_data/projects_auto/dcr.yml' },
  { name: 'boston', label: 'City of Boston (review only)', fetch: fetchBoston, file: '_data/projects_candidates/boston.yml' },
];

const reportPath = process.argv.includes('--report') ? process.argv[process.argv.indexOf('--report') + 1] : null;
const manual = readYaml('_data/projects.yml');
const overrides = readYaml('_data/projects_overrides.yml') || {};
const hidden = new Set((overrides.hide || []).map(normUrl));
const manualEntries = manual.sections.flatMap((s) => (s.projects || []).map((p) => ({ ...p, section: s.title })));
const manualByUrl = new Map(manualEntries.map((p) => [normUrl(p.url), p]));

// Mirror of the routing rule in _plugins/merge_projects.rb.
function sectionFor(source, title) {
  const rule = overrides.routing?.[source];
  if (!rule || typeof rule === 'string') return rule;
  const hit = Object.entries(rule).find(([pattern]) => pattern !== 'default' && new RegExp(pattern, 'i').test(title));
  return hit ? hit[1] : rule.default;
}

const lines = [];
const failures = [];
for (const src of SOURCES) {
  const previous = existsSync(join(ROOT, src.file)) ? readYaml(src.file)?.projects || [] : [];
  const previousUrls = new Set(previous.map((p) => normUrl(p.url)));
  let doc;
  try {
    doc = await src.fetch();
    writeGenerated(src.file, doc, { header: `${src.label} projects` });
  } catch (err) {
    failures.push(src.name);
    console.error(`::warning::${src.name} fetch failed, keeping previous data: ${err.message}`);
    lines.push(`### ${src.label}\n\n⚠️ Fetch failed, previous data kept: \`${err.message}\`\n`);
    continue;
  }

  const untracked = doc.projects.filter((p) => !manualByUrl.has(normUrl(p.url)) && !hidden.has(normUrl(p.url)));
  const isNew = (p) => (previousUrls.has(normUrl(p.url)) ? '' : ' 🆕');
  lines.push(`### ${src.label}\n\nFetched ${doc.projects.length} matching projects.\n`);
  if (src.name === 'boston') {
    if (untracked.length) {
      lines.push('Candidates not yet in `_data/projects.yml` or the hide list. **These are not shown on the site.** ' +
        'Copy good ones into `_data/projects.yml`; add the rest to `hide` in `_data/projects_overrides.yml`.\n');
      for (const p of untracked) lines.push(`- [${p.title}](${p.url})${isNew(p)} — ${p.status || 'no status'}, updated ${p.source_updated}, matched by ${p.matched_by}`);
    } else {
      lines.push('No untracked candidates.');
    }
  } else {
    const shown = untracked.filter((p) => sectionFor(src.name, p.title));
    if (shown.length) {
      lines.push('Will be **shown on the site** in addition to hand-written entries (merge this PR to publish; add a URL to `hide` to suppress):\n');
      for (const p of shown) lines.push(`- [${p.title}](${p.url})${isNew(p)} → \`${sectionFor(src.name, p.title)}\`${p.status ? ` (${p.status})` : ''}`);
    } else {
      lines.push('Nothing new beyond the hand-written entries.');
    }
    const drift = doc.projects
      .map((p) => [manualByUrl.get(normUrl(p.url)), p])
      .filter(([m, p]) => m && p.status && m.status !== p.status);
    if (drift.length) {
      lines.push('\nStatus differs from a hand-written entry (update `_data/projects.yml` if the agency is right):\n');
      for (const [m, p] of drift) lines.push(`- ${m.title}: ours \`${m.status || 'none'}\`, agency \`${p.status}\``);
    }
  }
  lines.push('');
}

// Check that hand-written links still resolve without redirects.
const linkProblems = [];
for (const p of manualEntries) {
  try {
    const res = await fetch(p.url, { redirect: 'manual', signal: AbortSignal.timeout(30_000) });
    if (res.status >= 300 && res.status < 400) linkProblems.push(`- ${p.title}: redirects to ${new URL(res.headers.get('location'), p.url)}`);
    else if (!res.ok) linkProblems.push(`- ${p.title}: HTTP ${res.status} (${p.url})`);
  } catch (err) {
    linkProblems.push(`- ${p.title}: ${err.message} (${p.url})`);
  }
}
lines.push('### Hand-written entries\n');
lines.push(linkProblems.length ? `Link problems:\n\n${linkProblems.join('\n')}` : `All ${manualEntries.length} links OK.`);

const report = `## Weekly project data refresh\n\n${lines.join('\n')}\n`;
if (reportPath) writeFileSync(reportPath, report);
else console.log(report);
if (failures.length === SOURCES.length) process.exit(1);
