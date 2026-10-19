module Caldav
  # Builds a 207 Multi-Status document
  class Multistatus
    include Namespaces

    def initialize
      @responses = []
      @sync_token = nil
    end

    attr_writer :sync_token

    # `found` maps Prop => block rendering the value in the builder; `missing` lists unsupported props
    def add(href, found: {}, missing: [])
      @responses << { href:, found:, missing: }
    end

    def add_not_found(href)
      @responses << { href:, status: "HTTP/1.1 404 Not Found" }
    end

    def to_xml
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml["d"].multistatus(XMLNS) do
          @responses.each { |response| render_response(xml, response) }
          xml["d"].public_send(:"sync-token", @sync_token) if @sync_token
        end
      end.to_xml
    end

    private

    def render_response(xml, response)
      xml["d"].response do
        xml["d"].href(response[:href])
        if response[:status]
          xml["d"].status(response[:status])
        else
          render_propstat(xml, response[:found], "HTTP/1.1 200 OK") if response[:found].any?
          render_propstat(xml, response[:missing].index_with(nil), "HTTP/1.1 404 Not Found") if response[:missing].any?
        end
      end
    end

    def render_propstat(xml, props, status)
      xml["d"].propstat do
        xml["d"].prop do
          props.each do |prop, renderer|
            if PREFIXES.key?(prop.namespace)
              xml[PREFIXES[prop.namespace]].public_send(:"#{prop.name}_") { renderer&.call(xml) }
            else
              xml.public_send(:"#{prop.name}_", xmlns: prop.namespace.to_s)
            end
          end
        end
        xml["d"].status(status)
      end
    end
  end
end
