module Caldav
  # WebDAV/CalDAV properties of the resources a connection exposes: its principal (which is also its calendar home),
  # its single calendar, the busy blocks in it and the RDVs RDV-SP put in it.
  class Properties
    include Namespaces

    Prop = RequestBody::Prop

    def self.prop(namespace, name) = Prop.new(namespace:, name:)

    RESOURCETYPE = prop(DAV, "resourcetype")
    GETETAG = prop(DAV, "getetag")
    CALENDAR_DATA = prop(CALDAV, "calendar-data")

    def initialize(connection, base_path:)
      @connection = connection
      @base_path = base_path
    end

    def home_href = "#{@base_path}/caldav/#{@connection.public_id}/"

    def calendar_href = "#{@base_path}#{@connection.calendar_path}"

    def event_href(name) = "#{calendar_href}#{name}"

    def home
      principal_props.merge(
        RESOURCETYPE => ->(xml) { xml["d"].collection },
        prop(DAV, "displayname") => text("rdvsp-bridges")
      )
    end

    def calendar
      token = @connection.sync_token
      principal_props.merge(
        RESOURCETYPE => lambda { |xml|
          xml["d"].collection
          xml["c"].calendar
        },
        prop(DAV, "displayname") => text(display_name),
        prop(APPLE, "calendar-color") => text("#000091"),
        prop(CS, "getctag") => text(token),
        prop(DAV, "sync-token") => text(token),
        GETETAG => text(%("#{token}")),
        prop(CALDAV, "supported-calendar-component-set") => ->(xml) { xml["c"].comp(name: "VEVENT") },
        prop(DAV, "supported-report-set") => lambda { |xml|
          %w[sync-collection].each { |name| supported_report(xml, "d", name) }
          %w[calendar-query calendar-multiget].each { |name| supported_report(xml, "c", name) }
        },
        prop(DAV, "current-user-privilege-set") => lambda { |xml|
          %w[read write write-content write-properties bind unbind read-current-user-privilege-set].each do |name|
            xml["d"].privilege { xml["d"].public_send(:"#{name}_") }
          end
        }
      )
    end

    def event(etag:, ics: nil)
      props = {
        RESOURCETYPE => nil,
        GETETAG => text(etag),
        prop(DAV, "getcontenttype") => text("text/calendar; charset=utf-8; component=vevent"),
      }
      props[CALENDAR_DATA] = text(ics) if ics
      props
    end

    # Splits the requested props between the ones we have and the ones we don't
    def self.select(available, requested:, allprop:)
      return { found: available.except(CALENDAR_DATA), missing: [] } if allprop

      { found: available.slice(*requested), missing: requested - available.keys }
    end

    private

    def prop(...) = self.class.prop(...)

    def text(value) = ->(xml) { xml.text(value) }

    def principal_props
      href = ->(xml) { xml["d"].href(home_href) }
      {
        prop(DAV, "current-user-principal") => href,
        prop(DAV, "principal-URL") => href,
        prop(CALDAV, "calendar-home-set") => href,
        prop(DAV, "owner") => href,
      }
    end

    def supported_report(xml, prefix, name)
      xml["d"].public_send(:"supported-report") { xml["d"].report { xml[prefix].public_send(:"#{name}_") } }
    end

    def display_name
      [@connection.account.provider.capitalize, @connection.provider_user_name.presence].compact.join(" – ")
    end
  end
end
