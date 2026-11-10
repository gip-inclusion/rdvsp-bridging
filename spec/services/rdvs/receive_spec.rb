require "rails_helper"

RSpec.describe Rdvs::Receive do
  let(:connection) { create(:connection) }
  let(:starts_at) { 2.days.from_now.change(hour: 10) }

  def receive(href_name = "#{SecureRandom.uuid}.ics", rdvsp_id: 1000, status: "CONFIRMED")
    link = "Voir sur RDV Service Public: https://rdv.example.fr/admin/organisations/1/rdvs/#{rdvsp_id}"
    ics = RdvspEmulator.ics(uid: href_name.delete_suffix(".ics"), summary: "RDV Accueil", description: link,
                            starts_at:, ends_at: starts_at + 30.minutes, status:)
    described_class.call(connection:, href_name:, ics:).rdv
  end

  it "stores the RDV and schedules its push" do
    rdv = receive(rdvsp_id: 1234)

    expect(rdv).to have_attributes(rdvsp_id: 1234, state: "pending", starts_at:)
    expect(PushRdvJob).to have_been_enqueued.with(rdv)
  end

  context "when RDV-SP has just tested the connection" do
    before { connection.open_baseline! }

    it "ignores the RDVs of its bulk export: stored without their content and never pushed" do
      rdv = receive

      expect(rdv).to have_attributes(ignored?: true, payload: nil, state: "synced", starts_at:)
      expect(PushRdvJob).not_to have_been_enqueued
    end

    it "pushes the RDVs received once the window has closed" do
      travel 61.seconds

      expect(receive).not_to be_ignored
      expect(PushRdvJob).to have_been_enqueued
    end

    it "keeps an ignored RDV ignored through its updates and cancellation" do
      href_name = "#{SecureRandom.uuid}.ics"
      receive(href_name)
      travel 2.minutes

      receive(href_name)
      rdv = receive(href_name, status: "CANCELLED")

      expect(rdv).to have_attributes(ignored?: true, cancelled?: true, payload: nil)
      expect(PushRdvJob).not_to have_been_enqueued
    end
  end

  it "keeps pushing an RDV it already pushed when RDV-SP re-sends it after another connection test" do
    href_name = "#{SecureRandom.uuid}.ics"
    receive(href_name)
    connection.open_baseline!

    expect(receive(href_name)).not_to be_ignored
    expect(PushRdvJob).to have_been_enqueued.twice
  end
end
