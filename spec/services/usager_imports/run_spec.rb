require "rails_helper"

RSpec.describe UsagerImports::Run, :rdvsp do
  let(:account) { create(:account, provider_company_domain: "acme") }
  let(:usager_import) do
    create(:usager_import, account:, rdvsp_organisation_id: 42, field_key: "abc123", option_id: "34")
  end
  let(:users_url) { "#{rdvsp_url}/api/v1/users" }

  before do
    create(:rdvsp_authorization, account:)
    stub_rdvsp_organisation_users(42, [])
  end

  def rejection(errors)
    { status: 422, body: { errors:, error_messages: [] }.to_json, headers: { "Content-Type" => "application/json" } }
  end

  it "creates each usager with a reference to its Pipedrive person, and records it" do
    stub_pipedrive_persons([pipedrive_person(7, email: [{ value: "ada@example.fr", primary: true }],
                                                phone: [{ value: "06 12 34 56 78", primary: true }])])
    create_user = stub_request(:post, users_url).with(body: {
      first_name: "Ada", last_name: "Lovelace", email: "ada@example.fr", phone_number: "06 12 34 56 78",
      organisation_ids: [42],
      external_reference: { external_id: "7", external_url: "https://acme.pipedrive.com/person/7" },
    }.to_json).to_return_json(body: { user: { id: 99 } })

    described_class.call(usager_import:)

    expect(create_user).to have_been_requested
    expect(account.imported_usagers.sole)
      .to have_attributes(provider_person_id: "7", rdvsp_user_id: 99, rdvsp_organisation_id: 42, usager_import:)
    expect(usager_import.reload).to have_attributes(state: "done", started_at: be_present, finished_at: be_present)
    expect(usager_import.counts).to include("selected" => 1, "to_create" => 1, "created" => 1)
  end

  it "creates the usager without e-mail and phone when RDV-SP refuses only those" do
    stub_pipedrive_persons([pipedrive_person(7, phone: [{ value: "12", primary: true }])])
    stub_request(:post, users_url).with(body: hash_including("phone_number" => "12"))
      .to_return(rejection(phone_number: [{ error: "invalid", value: "12" }]))
    retried = stub_request(:post, users_url).with { !JSON.parse(it.body).key?("phone_number") }
      .to_return_json(body: { user: { id: 99 } })

    described_class.call(usager_import:)

    expect(retried).to have_been_requested
    expect(usager_import.reload.counts).to include("created" => 0, "created_without_contact" => 1)
  end

  it "counts a usager RDV-SP already has from this application as imported, and other rejections by attribute" do
    stub_pipedrive_persons([pipedrive_person(7), pipedrive_person(8, first_name: "Grace")])
    stub_request(:post, users_url).with(body: hash_including("first_name" => "Ada"))
      .to_return(rejection("external_references.external_id": [{ error: "taken", value: "7" }]))
    stub_request(:post, users_url).with(body: hash_including("first_name" => "Grace"))
      .to_return(rejection(birth_date: [{ error: "invalid" }], last_name: [{ error: "blank" }]))

    described_class.call(usager_import:)

    expect(usager_import.reload.counts).to include("already_imported" => 1, "rejected" => 1, "created" => 0)
    expect(usager_import.rejections).to eq("birth_date, last_name" => 1)
    expect(account.imported_usagers).to be_empty
  end

  it "creates nothing the second time" do
    stub_pipedrive_persons([pipedrive_person(7)])
    create_user = stub_request(:post, users_url).to_return_json(body: { user: { id: 99 } })

    described_class.call(usager_import:)
    described_class.call(usager_import: create(:usager_import, account:, rdvsp_organisation_id: 42,
                                                               field_key: "abc123", option_id: "34"))

    expect(create_user).to have_been_requested.once
  end
end
