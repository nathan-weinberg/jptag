// Find City of Boston transportation pages that look relevant to JP, via the boston.gov Drupal JSON:API.
//
// boston.gov files projects under several content types with inconsistent neighborhood
// tagging, so results are noisy. They are written as review-only candidates and are
// NOT shown on the site; promote good ones into _data/projects.yml by hand.
import { getJSON, plainText, summarize, today, writeGenerated } from './lib.mjs';

const API = 'https://www.boston.gov/jsonapi';
const SITE = 'https://www.boston.gov';
const TRANSPORTATION = 'cbaddac9-adb0-4e55-b865-8b3368c1523a'; // taxonomy_term--contact "Transportation"
// Content type -> name of its department/contact field.
const TYPES = { article: 'field_contact', program_initiative_profile: 'field_contacts', project: 'field_contact' };
// Bare "Centre Street" is avoided: West Roxbury has one too.
const KEYWORDS = /jamaica plain|\bJP\b|columbus av|southwest corridor|forest hills|arborway|jamaicaway|egleston|jackson sq|hyde sq|south huntington|green st|lower south st|centre ?\/ ?south/i;
const JP_ZIP = '02130';
const JP_BBOX = { s: 42.295, n: 42.332, w: -71.128, e: -71.09 };

function inJp(attrs) {
  if (attrs.field_project_address?.[0]?.postal_code === JP_ZIP) return true;
  try {
    const geo = JSON.parse(attrs.field_project_gis_pts?.geojson || '{}');
    return (geo.geometries || []).some(({ coordinates: [x, y] = [] }) =>
      y > JP_BBOX.s && y < JP_BBOX.n && x > JP_BBOX.w && x < JP_BBOX.e);
  } catch {
    return false;
  }
}

export async function fetchBoston() {
  const projects = [];
  for (const [type, contactField] of Object.entries(TYPES)) {
    const extraFields = type === 'project' ? ',field_project_address,field_project_gis_pts,field_project_stage' : '';
    let url = `${API}/node/${type}?filter[status]=1&filter[${contactField}.id]=${TRANSPORTATION}` +
      `&fields[node--${type}]=drupal_internal__nid,title,path,changed,field_intro_text${extraFields}` +
      `${type === 'project' ? '&include=field_project_stage' : ''}&page[limit]=50`;
    while (url) {
      const page = await getJSON(url, { accept: 'application/vnd.api+json' });
      const stages = new Map((page.included || []).map((i) => [i.id, i.attributes?.name]));
      for (const { relationships, attributes: a } of page.data) {
        const intro = plainText(a.field_intro_text?.processed ?? a.field_intro_text?.value);
        const byKeyword = KEYWORDS.test(`${a.title} ${intro}`);
        const byLocation = type === 'project' && inJp(a);
        if (!byKeyword && !byLocation) continue;
        const stage = stages.get(relationships?.field_project_stage?.data?.id);
        if (stage === 'Completed') continue;
        projects.push({
          id: `bos-${a.drupal_internal__nid}`,
          title: a.title.trim(),
          description: summarize(intro),
          url: SITE + a.path.alias,
          ...(stage ? { status: stage } : {}),
          source_updated: a.changed.slice(0, 10),
          matched_by: byKeyword && byLocation ? 'keyword+location' : byKeyword ? 'keyword' : 'location',
        });
      }
      url = page.links?.next?.href;
    }
  }
  projects.sort((a, b) => b.source_updated.localeCompare(a.source_updated));
  return { source: 'boston', fetched: today(), review_only: true, projects };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const doc = await fetchBoston();
  const n = writeGenerated('_data/projects_candidates/boston.yml', doc, { header: 'City of Boston candidates (review only, not shown on the site)' });
  console.log(`boston: wrote ${n} candidates`);
}
