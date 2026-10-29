# jptag

Website for the Jamaica Plain Transportation Action Group, built with [Jekyll](https://jekyllrb.com/) and deployed to [GitHub Pages](https://docs.github.com/en/pages) via GitHub Actions.

## Editing content

| What | Where |
| --- | --- |
| Group name, mission statement | `_config.yml` (`title`, `mission`) |
| Google Group sign-up link | `_config.yml` → `google_group.url` |
| Google Calendar | `_config.yml` → `calendar.id`, `calendar.timezone` |
| Instagram embed (homepage) | `_config.yml` → `instagram_url` |
| Projects | `_data/projects.yml` (remember to bump `last_updated`) |

If the Google Group URL or calendar ID is left blank, the site shows a "coming soon" note instead.

The homepage Instagram preview uses Instagram's own profile embed. The account must be public and have embedding enabled (Instagram **Settings → Account privacy → Embeds**); otherwise only a plain "View JPTAG on Instagram" link shows.

### Google Calendar

No API key or credentials are needed. The calendar must be **public**:

1. In Google Calendar, open the calendar's **Settings and sharing**.
2. Under **Access permissions for events**, check **Make available to public**.
3. Under **Integrate calendar**, copy the **Calendar ID** (e.g. `abc123@group.calendar.google.com`) into `calendar.id`.

### Projects

Hand-written projects live in `_data/projects.yml`. Each section has a title, managing agency, optional note and emoji, and a list of projects with `title`, `description`, `url`, and optional `status`. A section with no projects shows "No active projects tracked right now." Hand-written entries are always shown and take precedence over fetched ones.

#### Automated refresh

`.github/workflows/refresh-projects.yml` runs every Monday (or on demand from the Actions tab) and opens a **"Projects: weekly data refresh"** pull request. Nothing reaches the site until a volunteer merges it. The PR description lists what would change.

| Source | How | Shown on site? |
| --- | --- | --- |
| MBTA | CMS feed behind mbta.com/projects, filtered to our routes | Yes, via `_data/projects_auto/mbta.yml` |
| DCR | mass.gov JSON:API, filtered to DCR pages about our parkways/parks | Yes, via `_data/projects_auto/dcr.yml` |
| City of Boston | boston.gov JSON:API, Transportation dept pages mentioning JP places | No. Candidates only, in `_data/projects_candidates/boston.yml`; copy good ones into `_data/projects.yml` |

`_data/projects_overrides.yml` controls fetched entries:

- `routing`: which section each source's projects go into.
- `hide`: URLs to never show. Add anything you reject in a refresh PR here, or it will be proposed again next week.

Never edit files under `_data/projects_auto/` or `_data/projects_candidates/` by hand; they are overwritten on every refresh.

To run the refresh locally (same Ruby as the site, no extra gems):

```sh
ruby scripts/refresh.rb
```

One-time setup: in **Settings → Actions → General → Workflow permissions**, check **Allow GitHub Actions to create and approve pull requests**.

## Local development

Requires Ruby 2.7+ (CI uses 3.3).

```sh
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000/>.

## Deployment

Pushing to `main` runs `.github/workflows/pages.yml`, which builds and deploys the site.

One-time setup: in the GitHub repo, go to **Settings → Pages → Build and deployment** and set **Source** to **GitHub Actions**.

If the site is served from a custom domain or a `<user>.github.io` repo, set `baseurl: ""` in `_config.yml` for local dev (the Actions build sets the base path automatically).
