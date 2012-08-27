require 'nokogiri'

class TentClient
  class Discovery
    attr_accessor :url, :profile_urls, :profile

    def initialize(client, url)
      @client, @url = client, url
    end

    def http
      @http ||= Faraday.new do |f|
        f.response :follow_redirects
        f.adapter *Array(@client.faraday_adapter)
      end
    end

    def perform
      @profile_urls = perform_head_discovery || perform_get_discovery || []
      @profile_urls.map! { |l| l =~ %r{\A/} ? URI.join(url, l).to_s : l }
    end

    def get_profile
      profile_urls.each do |url|
        res = @client.http.get(url)
        break @profile = res.body if res['Content-Type'] == PROFILE_MEDIA_TYPE
      end
    end

    def perform_head_discovery
      perform_header_discovery http.head(url)
    end

    def perform_get_discovery
      res = http.get(url)
      perform_header_discovery(res) || perform_html_discovery(res)
    end

    def perform_header_discovery(res)
      if header = res['Link']
        links = LinkHeader.parse(header).links
        tent_profiles = links.select { |l| l[:rel] == 'profile' && l[:type] == PROFILE_MEDIA_TYPE }.
                              map { |l| l.uri }
        tent_profiles unless tent_profiles.empty?
      end
    end

    def perform_html_discovery(res)
      return unless res['Content-Type'] == 'text/html'
      links = Nokogiri::HTML(res.body).css('link[rel=profile]')
      links.select { |l| l['type'] == PROFILE_MEDIA_TYPE }.map { |l| l['href'] }
    end
  end
end
