module Caldav
  module Namespaces
    DAV = "DAV:".freeze
    CALDAV = "urn:ietf:params:xml:ns:caldav".freeze
    CS = "http://calendarserver.org/ns/".freeze
    APPLE = "http://apple.com/ns/ical/".freeze

    PREFIXES = { DAV => "d", CALDAV => "c", CS => "cs", APPLE => "a" }.freeze
    XMLNS = PREFIXES.to_h { |uri, prefix| ["xmlns:#{prefix}", uri] }.freeze
  end
end
