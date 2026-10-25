# Merges automatically fetched projects (_data/projects_auto/*.yml) into the
# hand-written sections from _data/projects.yml at build time.
#
# - Hand-written entries are always shown first and win over fetched ones with the same URL.
# - Fetched entries are routed to a section and filtered by _data/projects_overrides.yml.
# - A missing or empty source is skipped, so the page never loses its hand-written entries.
module JPTAG
  class MergeProjects < Jekyll::Generator
    priority :highest

    def generate(site)
      data = site.data["projects"] or return
      overrides = site.data["projects_overrides"] || {}
      routing = overrides["routing"] || {}
      hidden = (overrides["hide"] || []).map { |url| norm(url) }

      sections = data["sections"].map { |s| s.merge("projects" => (s["projects"] || []).dup) }
      by_id = sections.to_h { |s| [s["id"], s] }
      seen = sections.flat_map { |s| s["projects"].map { |p| norm(p["url"]) } }

      fetched = []
      (site.data["projects_auto"] || {}).each do |source, doc|
        projects = doc.is_a?(Hash) ? doc["projects"] : nil
        if projects.nil? || projects.empty?
          Jekyll.logger.warn "Projects:", "auto source '#{source}' is empty or unreadable, skipping"
          next
        end
        fetched << doc["fetched"].to_s

        projects.each do |project|
          key = norm(project["url"])
          next if hidden.include?(key) || seen.include?(key)

          section = by_id[section_for(routing[source], project["title"])] or next
          section["projects"] << project.merge("auto" => true)
          seen << key
        end
      end

      site.data["projects"] = data.merge("sections" => sections, "auto_fetched" => fetched.max)
    end

    private

    def norm(url)
      url.to_s.strip.downcase.sub(%r{\Ahttps?://(www\.)?}, "").sub(/[?#].*\z/, "").sub(%r{/+\z}, "")
    end

    def section_for(rule, title)
      return rule unless rule.is_a?(Hash)

      match = rule.find { |pattern, _| pattern != "default" && title.to_s =~ /#{pattern}/i }
      match ? match.last : rule["default"]
    end
  end
end
