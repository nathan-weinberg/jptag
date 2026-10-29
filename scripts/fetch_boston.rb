# Find City of Boston transportation pages that look relevant to JP, via the boston.gov Drupal JSON:API.
#
# boston.gov files projects under several content types with inconsistent neighborhood
# tagging, so results are noisy. They are written as review-only candidates and are
# NOT shown on the site; promote good ones into _data/projects.yml by hand.
require_relative "lib"

module Refresh
  module Boston
    API = "https://www.boston.gov/jsonapi"
    SITE = "https://www.boston.gov"
    TRANSPORTATION = "cbaddac9-adb0-4e55-b865-8b3368c1523a" # taxonomy_term--contact "Transportation"
    # Content type -> name of its department/contact field.
    TYPES = { "article" => "field_contact", "program_initiative_profile" => "field_contacts", "project" => "field_contact" }.freeze
    # Bare "Centre Street" is avoided: West Roxbury has one too.
    KEYWORDS = %r{jamaica plain|\bJP\b|columbus av|southwest corridor|forest hills|arborway|jamaicaway|egleston|jackson sq|hyde sq|south huntington|green st|lower south st|centre ?/ ?south}i.freeze
    JP_ZIP = "02130"
    JP_BBOX = { s: 42.295, n: 42.332, w: -71.128, e: -71.09 }.freeze

    module_function

    def in_jp?(attrs)
      return true if attrs.dig("field_project_address", 0, "postal_code") == JP_ZIP

      geo = JSON.parse(attrs.dig("field_project_gis_pts", "geojson") || "{}")
      (geo["geometries"] || []).any? do |g|
        x, y = g["coordinates"]
        x && y && y > JP_BBOX[:s] && y < JP_BBOX[:n] && x > JP_BBOX[:w] && x < JP_BBOX[:e]
      end
    rescue JSON::ParserError, TypeError
      false
    end

    def fetch
      projects = []
      TYPES.each do |type, contact_field|
        is_project = type == "project"
        extra_fields = is_project ? ",field_project_address,field_project_gis_pts,field_project_stage" : ""
        url = "#{API}/node/#{type}?filter[status]=1&filter[#{contact_field}.id]=#{TRANSPORTATION}" \
              "&fields[node--#{type}]=drupal_internal__nid,title,path,changed,field_intro_text#{extra_fields}" \
              "#{is_project ? '&include=field_project_stage' : ''}&page[limit]=50"
        while url
          page = Refresh.get_json(url, accept: "application/vnd.api+json")
          stages = (page["included"] || []).to_h { |i| [i["id"], i.dig("attributes", "name")] }
          page["data"].each do |node|
            a = node["attributes"]
            intro = Refresh.plain_text(a.dig("field_intro_text", "processed") || a.dig("field_intro_text", "value"))
            by_keyword = KEYWORDS.match?("#{a['title']} #{intro}")
            by_location = is_project && in_jp?(a)
            next unless by_keyword || by_location

            stage = stages[node.dig("relationships", "field_project_stage", "data", "id")]
            next if stage == "Completed"

            projects << {
              "id" => "bos-#{a['drupal_internal__nid']}",
              "title" => a["title"].strip,
              "description" => Refresh.summarize(intro),
              "url" => SITE + a.dig("path", "alias"),
              "status" => stage,
              "source_updated" => a["changed"][0, 10],
              "matched_by" => if by_keyword && by_location then "keyword+location"
                              elsif by_keyword then "keyword"
                              else "location"
                              end,
            }.compact
          end
          url = page.dig("links", "next", "href")
        end
      end
      # Newest first; ties keep fetch order (sort_by isn't stable on its own).
      projects = projects.sort_by.with_index { |p, i| [p["source_updated"], -i] }.reverse
      { "source" => "boston", "fetched" => Refresh.today, "review_only" => true, "projects" => projects }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  n = Refresh.write_generated("_data/projects_candidates/boston.yml", Refresh::Boston.fetch,
                              "City of Boston candidates (review only, not shown on the site)")
  puts "boston: wrote #{n} candidates"
end
