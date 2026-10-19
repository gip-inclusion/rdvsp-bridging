require "rails_helper"

RSpec.describe "RDV Service Public's CalDAV client against the bridge" do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:connection) { create(:connection, account:, password: "s3cret-password") }
  let(:rdvsp) { RdvspEmulator.new(username: connection.username, password: "s3cret-password") }
  let(:calendar_url) { "#{TestServer.url}#{connection.calendar_path}" }

  before { account.update!(refreshed_at: Time.current) }

  after do
    [BusyBlock, BusyBlockChange, Rdv, Connection, Account].each(&:delete_all)
  end

  it "lets the agent pick the calendar from the server URL" do
    calendars = rdvsp.selectable_calendars("#{TestServer.url}/caldav/#{connection.public_id}/")

    expect(calendars.map(&:url)).to eq([calendar_url])
    expect(calendars.first.display_name).to eq("Pipedrive – Camille Martin")
    expect(calendars.first.current_user_privilege_set).to include("write")
  end

  it "also accepts the calendar URL directly" do
    expect(rdvsp.selectable_calendars(calendar_url).map(&:url)).to eq([calendar_url])
  end

  it "passes RDV-SP's connection check without storing the test event" do
    expect { rdvsp.configure!(calendar_url) }.not_to change(Rdv, :count)
    expect(enqueued_jobs).to be_empty
  end

  it "rejects wrong credentials" do
    intruder = RdvspEmulator.new(username: connection.username, password: "nope")

    expect { intruder.configure!(calendar_url) }.to raise_error(Calendav::RequestError)
  end

  it "imports busy blocks, then follows changes and deletions through sync tokens" do
    starts_at = 2.days.from_now.change(hour: 8, min: 0)
    connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)
    connection.upsert_busy_block!("2", starts_at: starts_at + 3.hours, ends_at: starts_at + 4.hours)
    rdvsp.configure!(calendar_url)

    rdvsp.import!
    expect(rdvsp.external_events.values).to contain_exactly(
      { starts_at:, ends_at: starts_at + 1.hour },
      { starts_at: starts_at + 3.hours, ends_at: starts_at + 4.hours }
    )

    connection.upsert_busy_block!("1", starts_at: starts_at + 30.minutes, ends_at: starts_at + 90.minutes)
    connection.remove_busy_block!("2")
    connection.upsert_busy_block!("3", starts_at: starts_at + 1.day, ends_at: starts_at + 1.day + 15.minutes)
    rdvsp.import!

    expect(rdvsp.external_events.values).to contain_exactly(
      { starts_at: starts_at + 30.minutes, ends_at: starts_at + 90.minutes },
      { starts_at: starts_at + 1.day, ends_at: starts_at + 1.day + 15.minutes }
    )
  end

  it "recovers from an unknown sync token with the full state" do
    connection.upsert_busy_block!("1", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    rdvsp.configure!(calendar_url)
    rdvsp.import!
    rdvsp.instance_variable_set(:@sync_token, "garbage")
    connection.remove_busy_block!("1")

    expect { rdvsp.import! }.not_to raise_error
    expect(rdvsp.external_events).to be_empty
  end

  it "receives RDVs, their updates and their deletion, and never re-imports them as busy" do
    rdvsp.configure!(calendar_url)
    uuid = SecureRandom.uuid
    starts_at = 3.days.from_now.change(hour: 14)

    rdvsp.export_rdv(uuid, starts_at:, ends_at: starts_at + 30.minutes)
    rdv = connection.rdvs.sole
    expect(rdv).to have_attributes(uid: uuid, starts_at:, ends_at: starts_at + 30.minutes, cancelled_at: nil)
    expect(rdvsp.exported_urls[uuid]).to eq("#{calendar_url}#{uuid}.ics")

    rdvsp.export_rdv(uuid, starts_at: starts_at + 1.hour, ends_at: starts_at + 90.minutes)
    expect(rdv.reload.starts_at).to eq(starts_at + 1.hour)

    rdvsp.import!
    expect(rdvsp.external_events).to be_empty

    rdvsp.delete_rdv(uuid)
    expect(rdv.reload.cancelled_at).to be_present
    expect(enqueued_jobs.count { it["job_class"] == "PushRdvJob" }).to eq(3)
  end

  it "treats an RDV-SP cancellation (STATUS:CANCELLED update) as a cancellation" do
    rdvsp.configure!(calendar_url)
    uuid = SecureRandom.uuid
    rdvsp.export_rdv(uuid, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes)
    rdvsp.export_rdv(uuid, starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes, status: "CANCELLED")

    expect(connection.rdvs.sole.cancelled_at).to be_present
  end
end
