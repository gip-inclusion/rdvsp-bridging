require "rails_helper"

RSpec.describe Google::BusyMapping do
  let(:connection) { create(:connection, account: create(:account, provider: "google"), provider_user_id: "primary") }
  let(:mapping) { described_class.new(connection) }
  let(:starts_at) { 1.day.from_now.change(hour: 8, min: 0) }

  it "uses the event's times" do
    expect(mapping.times_for(google_event(id: "a", starts_at:))).to eq(starts_at:, ends_at: starts_at + 1.hour)
  end

  it "ignores free, cancelled, declined, working-location events and the RDVs the bridge created" do
    [
      { "transparency" => "transparent" },
      { "status" => "cancelled" },
      { "eventType" => "workingLocation" },
      { "attendees" => [{ "self" => true, "responseStatus" => "declined" }] },
      { "extendedProperties" => { "private" => { "rdvsp_bridging_rdv" => "x.ics" } } },
    ].each { |change| expect(mapping.times_for(google_event(id: "a", **change.symbolize_keys))).to be_nil }
  end

  it "keeps out-of-office and tentative events busy" do
    expect(mapping.times_for(google_event(id: "a", eventType: "outOfOffice"))).to be_present
    expect(mapping.times_for(google_event(id: "a", status: "tentative"))).to be_present
  end

  it "ignores all-day events unless the connection asks for them" do
    event = google_event(id: "a", start: { "date" => "2026-11-02" }, end: { "date" => "2026-11-03" })
    expect(mapping.times_for(event)).to be_nil

    connection.update!(include_all_day: true)
    paris = Time.find_zone("Europe/Paris")
    expect(mapping.times_for(event)).to eq(starts_at: paris.parse("2026-11-02"), ends_at: paris.parse("2026-11-03"))
  end
end
