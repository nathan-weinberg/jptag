# Refresh all project sources, then write a Markdown review report.
#
# Usage: ruby scripts/refresh.rb [--report path/to/report.md]
# Each source is isolated: if one fails, its previous data file is kept and the others still run.
require_relative "fetch_mbta"
require_relative "fetch_dcr"
require_relative "fetch_boston"

include Refresh

SOURCES = [
  { name: "mbta", label: "MBTA", fetcher: Refresh::MBTA, file: "_data/projects_auto/mbta.yml" },
  { name: "dcr", label: "DCR (mass.gov)", fetcher: Refresh::DCR, file: "_data/projects_auto/dcr.yml" },
  { name: "boston", label: "City of Boston (review only)", fetcher: Refresh::Boston, file: "_data/projects_candidates/boston.yml" },
].freeze

report_path = (i = ARGV.index("--report")) && ARGV[i + 1]
manual = read_yaml("_data/projects.yml")
overrides = read_yaml("_data/projects_overrides.yml") || {}
hidden = (overrides["hide"] || []).map { |u| norm_url(u) }
manual_entries = manual["sections"].flat_map { |s| (s["projects"] || []).map { |p| p.merge("section" => s["title"]) } }
manual_by_url = manual_entries.to_h { |p| [norm_url(p["url"]), p] }

# Mirror of the routing rule in _plugins/merge_projects.rb.
def section_for(rule, title)
  return rule unless rule.is_a?(Hash)

  match = rule.find { |pattern, _| pattern != "default" && title =~ /#{pattern}/i }
  match ? match.last : rule["default"]
end

lines = []
failures = []
SOURCES.each do |src|
  previous = File.exist?(File.join(ROOT, src[:file])) ? (read_yaml(src[:file]) || {})["projects"] || [] : []
  previous_urls = previous.map { |p| norm_url(p["url"]) }
  begin
    doc = src[:fetcher].fetch
    write_generated(src[:file], doc, "#{src[:label]} projects")
  rescue StandardError => e
    failures << src[:name]
    warn "::warning::#{src[:name]} fetch failed, keeping previous data: #{e.message}"
    lines << "### #{src[:label]}\n\n⚠️ Fetch failed, previous data kept: `#{e.message}`\n"
    next
  end

  untracked = doc["projects"].reject { |p| manual_by_url.key?(norm_url(p["url"])) || hidden.include?(norm_url(p["url"])) }
  is_new = ->(p) { previous_urls.include?(norm_url(p["url"])) ? "" : " 🆕" }
  lines << "### #{src[:label]}\n\nFetched #{doc['projects'].length} matching projects.\n"
  if src[:name] == "boston"
    if untracked.any?
      lines << "Candidates not yet in `_data/projects.yml` or the hide list. **These are not shown on the site.** " \
               "Copy good ones into `_data/projects.yml`; add the rest to `hide` in `_data/projects_overrides.yml`.\n"
      untracked.each do |p|
        lines << "- [#{p['title']}](#{p['url']})#{is_new.(p)} — #{p['status'] || 'no status'}, " \
                 "updated #{p['source_updated']}, matched by #{p['matched_by']}"
      end
    else
      lines << "No untracked candidates."
    end
  else
    rule = (overrides["routing"] || {})[src[:name]]
    shown = untracked.select { |p| section_for(rule, p["title"]) }
    if shown.any?
      lines << "Will be **shown on the site** in addition to hand-written entries " \
               "(merge this PR to publish; add a URL to `hide` to suppress):\n"
      shown.each do |p|
        status = p["status"] ? " (#{p['status']})" : ""
        lines << "- [#{p['title']}](#{p['url']})#{is_new.(p)} → `#{section_for(rule, p['title'])}`#{status}"
      end
    else
      lines << "Nothing new beyond the hand-written entries."
    end
    drift = doc["projects"].filter_map do |p|
      m = manual_by_url[norm_url(p["url"])]
      [m, p] if m && p["status"] && m["status"] != p["status"]
    end
    if drift.any?
      lines << "\nStatus differs from a hand-written entry (update `_data/projects.yml` if the agency is right):\n"
      drift.each { |m, p| lines << "- #{m['title']}: ours `#{m['status'] || 'none'}`, agency `#{p['status']}`" }
    end
  end
  lines << ""
end

# Check that hand-written links still resolve without redirects.
link_problems = manual_entries.filter_map do |p|
  uri = URI(p["url"])
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 30, read_timeout: 30) do |http|
    http.get(uri.request_uri, "User-Agent" => USER_AGENT)
  end
  if res.is_a?(Net::HTTPRedirection)
    "- #{p['title']}: redirects to #{URI.join(p['url'], res['location'])}"
  elsif !res.is_a?(Net::HTTPSuccess)
    "- #{p['title']}: HTTP #{res.code} (#{p['url']})"
  end
rescue StandardError => e
  "- #{p['title']}: #{e.message} (#{p['url']})"
end
lines << "### Hand-written entries\n"
lines << (link_problems.any? ? "Link problems:\n\n#{link_problems.join("\n")}" : "All #{manual_entries.length} links OK.")

report = "## Weekly project data refresh\n\n#{lines.join("\n")}\n"
report_path ? File.write(report_path, report) : puts(report)
exit 1 if failures.length == SOURCES.length
