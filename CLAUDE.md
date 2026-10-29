# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Static Jekyll site for the Jamaica Plain Transportation Action Group (JPTAG), served at https://jptag.org via GitHub Pages. No JavaScript build, no plugins beyond stock Jekyll 4, no tests or linter.

## Commands

```sh
bundle install
bundle exec jekyll serve   # http://localhost:4000/ — restart after editing _config.yml (not hot-reloaded)
bundle exec jekyll build   # quickest way to check that Liquid/YAML changes render
ruby scripts/refresh.rb    # refetch _data/projects_auto/ and _data/projects_candidates/ (stdlib only, no bundle needed)
```

Requires Ruby 2.7+; CI uses 3.3. Always run Ruby through rvm with the version in `.ruby-version` (the system default is 2.7, which lacks the bundled gems): either `rvm use 3.3` first, or prefix commands with `~/.rvm/bin/rvm 3.3 do` (e.g. `~/.rvm/bin/rvm 3.3 do bundle exec jekyll build`) when `rvm use` isn't available, as in non-login shells. Don't change `PATH`/`GEM_HOME` by hand. Pushing to `main` deploys via `.github/workflows/pages.yml`, which builds with `JEKYLL_ENV=production` and passes `--baseurl` from `actions/configure-pages`.

## Commits

Always sign off commits: use `git commit -s` so each message ends with a `Signed-off-by:` trailer.

## How the site is wired

- **Content lives in data, not pages.** Most edits are to `_config.yml` (title, mission, Google Group URL, calendar ID/timezone, Instagram URL, nav items) or `_data/projects.yml`. The three pages (`index.md`, `calendar.md`, `projects.md`) are Liquid templates that render those values; all use `_layouts/default.html`, which pulls in `_includes/nav.html` (driven by `site.nav`).
- **Empty-value fallbacks.** Pages check `site.google_group.url`, `site.calendar.id`, and `site.instagram_url` against `""` and show a "coming soon" notice (or nothing) when blank. Preserve this pattern when adding new configurable integrations.
- **Third-party embeds need no credentials.** The calendar is a Google Calendar iframe of a *public* calendar; the homepage uses Instagram's `embed.js` profile embed, which falls back to a plain link if the account disallows embedding.
- **Projects page** iterates `site.data.projects.sections`. Each section's `id` is used as the in-page anchor for the TOC; `emoji`, `note`, and per-project `status` are optional. Whenever `_data/projects.yml` changes, bump its `last_updated` (YYYY-MM-DD) — it's displayed in the page footnote.
- **URLs** must go through `relative_url` so the site works under whatever base path the Actions build sets. Keep `baseurl: ""` in `_config.yml` (custom domain).
- Styling is a single hand-written stylesheet at `assets/css/style.css`.
- Repo-only files (README, Gemfile, vendor) are listed under `exclude` in `_config.yml`; add new non-site files there too.
