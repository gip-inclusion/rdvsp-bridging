require "rails_helper"

RSpec.describe Pipedrive::RdvActivity do
  subject(:attributes) { described_class.new(rdv).attributes }

  let(:account) { create(:account, usager_details:) }
  let(:usager_details) { false }
  let(:connection) { create(:connection, account:, provider_user_id: "42") }
  let(:rdv) do
    create(:rdv, connection:, starts_at: Time.zone.parse("2026-10-22 13:00 UTC"),
                 ends_at: Time.zone.parse("2026-10-22 13:45 UTC"), payload:)
  end
  let(:payload) do
    {
      "summary" => "Jeanne Dupont - Entretien",
      "description" => "RDV Téléphonique Voir sur RDV Solidarités: https://rdv.example/admin/organisations/1/rdvs/42" \
                       "\nContexte : situation familiale",
      "location" => "06 12 34 56 78",
    }
  end

  it "maps times in UTC, the owner and the dedicated type" do
    expect(attributes).to include(owner_id: 42, type: "rdv_service_public", due_date: "2026-10-22",
                                  due_time: "13:00", duration: "00:45", busy: true, done: false)
  end

  it "always links to the RDV in RDV-SP, even when the link isn't at the start of a line" do
    expect(attributes[:note]).to include('<a href="https://rdv.example/admin/organisations/1/rdvs/42">')
    expect(attributes[:note]).to include("aucun effet sur le rendez-vous")
  end

  context "without usager details" do
    it "drops anything that could identify the usager" do
      expect(attributes[:subject]).to eq("RDV Service Public")
      expect(attributes).not_to have_key(:location)
      expect(attributes[:note]).not_to include("Contexte")
    end

    it "keeps RDV-SP's non-sensitive summary and visio URLs" do
      rdv.update!(payload: payload.merge("summary" => "RDV Entretien", "location" => "https://visio.example/abc"))

      expect(attributes[:subject]).to eq("RDV Entretien")
      expect(attributes[:location]).to eq(value: "https://visio.example/abc")
    end
  end

  context "with usager details" do
    let(:usager_details) { true }

    it "passes RDV-SP's data through" do
      expect(attributes[:subject]).to eq("Jeanne Dupont - Entretien")
      expect(attributes[:location]).to eq(value: "06 12 34 56 78")
      expect(attributes[:note]).to include("Contexte : situation familiale")
    end
  end

  it "falls back to the meeting type when the account has no dedicated type" do
    account.update!(rdv_activity_type_key: nil)

    expect(attributes[:type]).to eq("meeting")
  end
end
