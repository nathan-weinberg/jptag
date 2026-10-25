// Fetch DCR project pages for our parkways/parks from the mass.gov Drupal JSON:API.
//
// mass.gov's CDN returns 403 for most custom User-Agents but accepts Node's default
// fetch headers, so requests here deliberately do not set one.
import { getJSON, plainText, summarize, today, writeGenerated } from './lib.mjs';

const API = 'https://www.mass.gov/jsonapi';
const SITE = 'https://www.mass.gov';
const DCR_ORG = 'f945eecf-3201-4e27-9081-0945f0b23c59'; // node--org_page "Department of Conservation & Recreation"
const KEYWORDS = ['Arborway', 'Jamaicaway', 'Southwest Corridor', 'Jamaica Pond', 'Olmsted Park', 'Forest Hills'];

// JSON:API OR-group: title CONTAINS any keyword.
function titleFilter() {
  let q = '&filter[kw][group][conjunction]=OR';
  KEYWORDS.forEach((k, i) => {
    const f = `filter[kw${i}][condition]`;
    q += `&${f}[path]=title&${f}[operator]=CONTAINS&${f}[value]=${encodeURIComponent(k)}&${f}[memberOf]=kw`;
  });
  return q;
}

export async function fetchDcr() {
  let url = `${API}/node/info_details?filter[status]=1&filter[field_organizations.id]=${DCR_ORG}${titleFilter()}` +
    '&fields[node--info_details]=title,path,changed,field_short_desc&page[limit]=50';
  const nodes = [];
  while (url) {
    const page = await getJSON(url, { userAgent: null, accept: 'application/vnd.api+json' });
    nodes.push(...page.data);
    url = page.links?.next?.href;
  }

  const projects = nodes.map(({ id, attributes: a }) => ({
    id: `dcr-${id.slice(0, 8)}`,
    title: a.title.trim(),
    description: summarize(plainText(a.field_short_desc?.value ?? a.field_short_desc)),
    url: SITE + a.path.alias,
    source_updated: (a.changed || '').slice(0, 10) || undefined,
  }));
  projects.sort((a, b) => a.title.localeCompare(b.title));
  return { source: 'dcr', fetched: today(), projects };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const doc = await fetchDcr();
  const n = writeGenerated('_data/projects_auto/dcr.yml', doc, { header: `DCR projects matching: ${KEYWORDS.join(', ')}` });
  console.log(`dcr: wrote ${n} projects`);
}
