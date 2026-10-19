module Caldav
  # Parses the XML body of PROPFIND and REPORT requests
  class RequestBody
    include Namespaces

    Prop = Data.define(:namespace, :name)

    def initialize(raw)
      @document = raw.blank? ? nil : Nokogiri::XML(raw, &:nonet)
    end

    def root_name = @document&.root&.name

    def allprop? = @document.nil? || @document.root.at_xpath("d:allprop", "d" => DAV).present?

    def props
      return [] if @document.nil?

      @document.root.xpath("d:prop/*", "d" => DAV).map { Prop.new(namespace: it.namespace&.href, name: it.name) }
    end

    def sync_token = @document&.at_xpath("/d:sync-collection/d:sync-token", "d" => DAV)&.text.to_s.strip

    def hrefs = @document ? @document.xpath("/c:calendar-multiget/d:href", "d" => DAV, "c" => CALDAV).map(&:text) : []

    def time_range
      node = @document&.at_xpath("//c:time-range", "c" => CALDAV)
      return if node.nil?

      from = node["start"].presence && Time.zone.parse(node["start"])
      to = node["end"].presence && Time.zone.parse(node["end"])
      (from || Time.zone.at(0))...(to || 100.years.from_now)
    end
  end
end
