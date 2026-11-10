require "rails_helper"

RSpec.describe Caldav::IncomingEvent do
  def event(description)
    described_class.new(uid: "u", starts_at: Time.current, ends_at: 1.hour.from_now, summary: "RDV Accueil",
                        description:, location: "", cancelled: false)
  end

  it "reads RDV-SP's id for the RDV from its link" do
    description = "Voir sur RDV Service Public: https://www.rdv-solidarites.fr/admin/organisations/12/rdvs/1259524"

    expect(event(description).rdvsp_id).to eq(1_259_524)
  end

  it "ignores links in the free-text context, which anyone booking can write" do
    description = "RDV Téléphonique \nContexte : voir /admin/organisations/1/rdvs/999999999"

    expect(event(description).rdvsp_id).to be_nil
  end

  it "has no id without a link" do
    expect(event("").rdvsp_id).to be_nil
  end
end
