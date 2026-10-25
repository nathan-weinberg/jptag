// Fetch MBTA projects tagged with the routes we follow.
//
// Source: the CMS feed behind mbta.com/projects (undocumented; URL shape comes from
// lib/cms/repo.ex in github.com/mbta/dotcom). /cms/teasers/any/<route_id> filters by route.
import { getJSON, plainText, summarize, today, writeGenerated } from './lib.mjs';

const CMS = 'https://live-mbta.pantheonsite.io';
const SITE = 'https://www.mbta.com';
const ROUTES = ['Orange', '14', '22', '29', '35', '36', '38', '39', '41'];
const MODE_TAGS = new Set(['bus', 'subway', 'commuter_rail', 'ferry', 'local_bus']);
// Projects tagged with many routes are systemwide programs; keep them only if they mention JP-area places.
const MAX_TAGS = 4;
const JP_PLACES = /forest hills|green st|stony brook|jackson sq|roxbury crossing|jamaica plain|centre st|south st|columbus av|egleston|hyde sq|arborway/i;

export async function fetchMbta() {
  const byId = new Map();
  for (const route of ROUTES) {
    const items = await getJSON(`${CMS}/cms/teasers/any/${encodeURIComponent(route)}?type[]=project&items_per_page=50`);
    if (!Array.isArray(items)) throw new Error(`unexpected response for route ${route}`);
    for (const it of items) {
      const seen = byId.get(it.nid);
      if (seen) seen.matched.add(route);
      else byId.set(it.nid, { ...it, matched: new Set([route]) });
    }
  }

  const projects = [];
  for (const it of byId.values()) {
    if (it.field_project_status === 'Complete') continue;
    const tags = (it.field_related_transit || []).map((t) => t.data?.gtfs_id);
    const text = plainText(`${it.title} ${it.text}`);
    const systemwide = tags.length > MAX_TAGS || tags.some((t) => MODE_TAGS.has(t));
    const orangeOnly = [...it.matched].every((r) => r === 'Orange');
    // Orange Line work is line-wide (Oak Grove to Forest Hills), so require a JP-area mention.
    if ((systemwide || orangeOnly) && !JP_PLACES.test(text)) continue;

    projects.push({
      id: `mbta-${it.nid}`,
      title: plainText(it.title),
      description: summarize(plainText(it.text)),
      url: SITE + it.path,
      ...(it.field_project_status ? { status: it.field_project_status } : {}),
      source_updated: it.updated || undefined,
      routes: [...it.matched],
    });
  }
  projects.sort((a, b) => a.title.localeCompare(b.title));
  return { source: 'mbta', fetched: today(), projects };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const doc = await fetchMbta();
  const n = writeGenerated('_data/projects_auto/mbta.yml', doc, { header: `MBTA projects for routes ${ROUTES.join(', ')}` });
  console.log(`mbta: wrote ${n} projects`);
}
