# Fetch DCR project pages for our parkways/parks from the mass.gov Drupal JSON:API.
require_relative "lib"

module Refresh
  module DCR
    API = "https://www.mass.gov/jsonapi"
    SITE = "https://www.mass.gov"
    DCR_ORG = "f945eecf-3201-4e27-9081-0945f0b23c59" # node--org_page "Department of Conservation & Recreation"
    KEYWORDS = ["Arborway", "Jamaicaway", "Southwest Corridor", "Jamaica Pond", "Olmsted Park", "Forest Hills"].freeze

    module_function

    # JSON:API OR-group: title CONTAINS any keyword.
    def title_filter
      KEYWORDS.each_with_index.map do |k, i|
        f = "filter[kw#{i}][condition]"
        "&#{f}[path]=title&#{f}[operator]=CONTAINS&#{f}[value]=#{ERB::Util.url_encode(k)}&#{f}[memberOf]=kw"
      end.join.prepend("&filter[kw][group][conjunction]=OR")
    end

    def fetch
      url = "#{API}/node/info_details?filter[status]=1&filter[field_organizations.id]=#{DCR_ORG}#{title_filter}" \
            "&fields[node--info_details]=title,path,changed,field_short_desc&page[limit]=50"
      nodes = []
      while url
        page = Refresh.get_json(url, accept: "application/vnd.api+json")
        nodes.concat(page["data"])
        url = page.dig("links", "next", "href")
      end

      projects = nodes.map do |node|
        a = node["attributes"]
        desc = a["field_short_desc"]
        {
          "id" => "dcr-#{node['id'][0, 8]}",
          "title" => a["title"].strip,
          "description" => Refresh.summarize(Refresh.plain_text(desc.is_a?(Hash) ? desc["value"] : desc)),
          "url" => SITE + a.dig("path", "alias"),
          "source_updated" => a["changed"]&.slice(0, 10),
        }.compact
      end
      { "source" => "dcr", "fetched" => Refresh.today, "projects" => projects.sort_by { |p| p["title"].downcase } }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  n = Refresh.write_generated("_data/projects_auto/dcr.yml", Refresh::DCR.fetch,
                              "DCR projects matching: #{Refresh::DCR::KEYWORDS.join(', ')}")
  puts "dcr: wrote #{n} projects"
end
