require "calendav"
require "icalendar/tzinfo"

# Reproduces, with the same gem and the same logic, what RDV Service Public does with a CalDAV calendar
# (Agents::CaldavSyncController, Caldav::ImportAbsencesFromCaldavJob and Caldav::ExportRdvToCaldavJob).
class RdvspEmulator
  attr_reader :agenda_url, :sync_token, :external_events, :exported_urls

  def initialize(username:, password:)
    @username = username
    @password = password
    @external_events = {}
    @exported_urls = {}
  end

  # Agents::CaldavSyncController#calendar_selection
  def selectable_calendars(url)
    client(url).calendars.list.select { |c| c.components.include?("VEVENT") }
  end

  # Agents::CaldavSyncController#caldav_config_error, then saving the agenda URL
  def configure!(agenda_url)
    @agenda_url = agenda_url
    client.principal_url
    raise "sync-token required by RDV-SP" if client.calendars.find(agenda_url, sync: true).sync_token.blank?

    uuid = SecureRandom.uuid
    test_event = client.events.create(agenda_url, "rdvsp-connection-test-#{uuid}.ics", ics(uid: uuid, summary: "Test"))
    client.events.delete(test_event.url)
  end

  # Caldav::ImportAbsencesFromCaldavJob#perform
  def import!
    if @sync_token
      collection = client.calendars.sync(agenda_url, @sync_token)
      updated = collection.changes.select { it.calendar_data && it.send(:inner_event) }.select { consider_busy?(it) }
      deleted = collection.changes.select { it.calendar_data && it.send(:inner_event) }.reject { consider_busy?(it) }
        .map(&:url)
      deleted += collection.changes.reject(&:calendar_data).map(&:url)
      deleted += collection.deletions
      new_token = collection.sync_token
    else
      new_token = client.calendars.find(agenda_url, sync: true).sync_token
      updated = client.events.list(agenda_url)
      deleted = []
    end

    updated = updated.reject { it.url.in?(exported_urls.values) }
    updated = updated.select { consider_busy?(it) }.select { it.dtend.present? }
    updated.each do |event|
      @external_events[event.url] = { starts_at: event.dtstart.to_time, ends_at: event.dtend.to_time }
    end
    deleted.each { @external_events.delete(it) }
    @sync_token = new_token
  end

  # Caldav::ExportRdvToCaldavJob, create and update
  def export_rdv(uuid, starts_at:, ends_at:, summary: "RDV Accueil", description: "", status: "CONFIRMED")
    body = ics(uid: uuid, summary:, description:, starts_at:, ends_at:, status:)
    if exported_urls[uuid]
      client.events.update(exported_urls[uuid], body)
    else
      exported_urls[uuid] = client.events.create(agenda_url, "#{uuid}.ics", body).url
    end
  end

  # Caldav::ExportRdvToCaldavJob, delete
  def delete_rdv(uuid)
    client.events.delete(exported_urls.delete(uuid))
  end

  private

  def client(url = agenda_url)
    Calendav::Client.new(
      Calendav::Credentials::Standard.new(host: url, username: @username, password: @password,
                                          authentication: :basic_auth)
    )
  end

  def consider_busy?(event)
    if event.send(:inner_event).rrule&.first&.valid?
      event.calendar_data.include?("TRANSP:OPAQUE")
    else
      event.transp != "TRANSPARENT"
    end
  end

  # Same shape as IcalFormatters::Ics.from_payload
  def ics(uid:, summary:, description: "", starts_at: Time.current, ends_at: 1.hour.from_now, status: "CONFIRMED")
    tzid = "Europe/Paris"
    cal = Icalendar::Calendar.new
    cal.add_timezone(TZInfo::Timezone.get(tzid).ical_timezone(starts_at))
    cal.prodid = "RDV Solidarités"
    cal.event do |event|
      event.uid = uid
      event.status = status
      event.dtstart = Icalendar::Values::DateTime.new(starts_at.in_time_zone(tzid), "tzid" => tzid)
      event.dtend = Icalendar::Values::DateTime.new(ends_at.in_time_zone(tzid), "tzid" => tzid)
      event.attendee = [Icalendar::Values::CalAddress.new("mailto:agent@example.fr", { "PARTSTAT" => "ACCEPTED" })]
      event.summary = summary
      event.sequence = 0
      event.description = description
      event.organizer = "mailto:secretariat@example.fr"
      event.categories = ["RDV Service Public"]
    end
    cal.ip_method = "REQUEST"
    cal.to_ical
  end
end
