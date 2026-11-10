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
end
