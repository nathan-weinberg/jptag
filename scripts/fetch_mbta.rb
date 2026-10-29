# Fetch MBTA projects tagged with the routes we follow.
#
# Source: the CMS feed behind mbta.com/projects (undocumented; URL shape comes from
# lib/cms/repo.ex in github.com/mbta/dotcom). /cms/teasers/any/<route_id> filters by route.
require_relative "lib"

module Refresh
  module MBTA
    CMS = "https://live-mbta.pantheonsite.io"
    SITE = "https://www.mbta.com"
    ROUTES = %w[Orange 14 22 29 35 36 38 39 41].freeze
    MODE_TAGS = %w[bus subway commuter_rail ferry local_bus].freeze
    # Projects tagged with many routes are systemwide programs; keep them only if they mention JP-area places.
    MAX_TAGS = 4
    JP_PLACES = /forest hills|green st|stony brook|jackson sq|roxbury crossing|jamaica plain|centre st|south st|columbus av|egleston|hyde sq|arborway/i.freeze

    module_function

    def fetch
      by_id = {}
      ROUTES.each do |route|
        items = Refresh.get_json("#{CMS}/cms/teasers/any/#{ERB::Util.url_encode(route)}?type[]=project&items_per_page=50")
        raise "unexpected response for route #{route}" unless items.is_a?(Array)

        items.each { |it| (by_id[it["nid"]] ||= it.merge("matched" => []))["matched"] << route }
      end

      projects = by_id.values.filter_map do |it|
        next if it["field_project_status"] == "Complete"

        tags = (it["field_related_transit"] || []).map { |t| t.dig("data", "gtfs_id") }
        text = Refresh.plain_text("#{it['title']} #{it['text']}")
        systemwide = tags.length > MAX_TAGS || tags.any? { |t| MODE_TAGS.include?(t) }
        orange_only = it["matched"].all?("Orange")
        # Orange Line work is line-wide (Oak Grove to Forest Hills), so require a JP-area mention.
        next if (systemwide || orange_only) && text !~ JP_PLACES

        {
          "id" => "mbta-#{it['nid']}",
          "title" => Refresh.plain_text(it["title"]),
          "description" => Refresh.summarize(Refresh.plain_text(it["text"])),
          "url" => SITE + it["path"],
          "status" => it["field_project_status"],
          "source_updated" => it["updated"],
          "routes" => it["matched"],
        }.compact
      end
      { "source" => "mbta", "fetched" => Refresh.today, "projects" => projects.sort_by { |p| p["title"].downcase } }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  n = Refresh.write_generated("_data/projects_auto/mbta.yml", Refresh::MBTA.fetch,
                              "MBTA projects for routes #{Refresh::MBTA::ROUTES.join(', ')}")
  puts "mbta: wrote #{n} projects"
end
