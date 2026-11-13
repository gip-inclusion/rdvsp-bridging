require "rails_helper"

RSpec.describe UsagerImports::Transfer, :rdvsp do
  let(:account) { create(:account, provider_company_id: "13579", provider_company_domain: "acme") }
  let(:transfer) { described_class.new(account:, organisation_id: 42) }
  let(:person) { Pipedrive::Beneficiaries::Person.new(id: "7", first_name: "Ada", last_name: "Lovelace", email: nil, phone: nil) }

  before { create(:rdvsp_authorization, account:) }

  it "creates the person as a usager of the organisation, and records it" do
    stub_request(:post, "#{rdvsp_url}/api/v1/users").with(body: {
      first_name: "Ada", last_name: "Lovelace", organisation_ids: [42],
      external_reference: { external_id: "pipedrive-13579-7", external_url: "https://acme.pipedrive.com/person/7" },
    }.to_json).to_return_json(body: { user: { id: 99 } })

    created = transfer.create(person)

    expect(created.without_contact).to be(false)
    expect(created.imported_usager)
      .to have_attributes(account:, provider_person_id: "7", rdvsp_user_id: 99, rdvsp_organisation_id: 42,
                          usager_import: nil)
  end

  it "records a person who already is a usager of the organisation" do
    expect(transfer.record(person, 98))
      .to have_attributes(account:, provider_person_id: "7", rdvsp_user_id: 98, rdvsp_organisation_id: 42)
  end
end
