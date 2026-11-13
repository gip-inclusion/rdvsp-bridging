require "rails_helper"

RSpec.describe UsagerImports::RdvPerson, :rdvsp do
  let(:account) { create(:account) }
  let(:rdv_person) { described_class.new(account) }

  def stub_participants(*user_ids, status: 200)
    stub_request(:get, "#{rdvsp_url}/api/v1/rdvs").with(query: hash_including("id" => "555"))
      .to_return_json(status:, body: { rdvs: [{ id: 555, participations: user_ids.map { { user: { id: it } } } }] })
  end

  context "with an RDV-SP authorization" do
    before { create(:rdvsp_authorization, account:) }

    it "gives the person of the RDV's only participant transferred by the bridge" do
      create(:imported_usager, account:, provider_person_id: "3", rdvsp_user_id: 99)
      stub_participants(98, 99)

      expect(rdv_person.person_id(555)).to eq("3")
    end

    it "gives none when no participant, or several, were transferred" do
      stub_participants(98)
      expect(rdv_person.person_id(555)).to be_nil

      create(:imported_usager, account:, provider_person_id: "3", rdvsp_user_id: 98)
      create(:imported_usager, account:, provider_person_id: "4", rdvsp_user_id: 99)
      stub_participants(98, 99)
      expect(rdv_person.person_id(555)).to be_nil
    end

    it "gives none when RDV-SP fails" do
      stub_participants(99, status: 500)

      expect(rdv_person.person_id(555)).to be_nil
    end
  end

  it "asks nothing without an RDV-SP id or an authorization" do
    expect(rdv_person.person_id(555)).to be_nil
    create(:rdvsp_authorization, account:, lost_at: Time.current)
    expect(described_class.new(account.reload).person_id(555)).to be_nil
    expect(described_class.new(account).person_id(nil)).to be_nil
  end
end
