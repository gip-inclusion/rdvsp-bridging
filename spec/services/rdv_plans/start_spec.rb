require "rails_helper"

RSpec.describe RdvPlans::Start, :rdvsp do
  let(:account) { create(:account, provider_company_id: "13579", provider_company_domain: "acme") }
  let(:result) { described_class.call(account:, person_id: "7", return_url: "https://bridge.example/back") }
  let(:plan_url) { "#{rdvsp_url}/agents/rdv_plans/5" }

  before { create(:rdvsp_authorization, account:) }

  def stub_rdv_plan(user_id)
    stub_request(:post, "#{rdvsp_url}/api/v1/rdv_plans").with(body: {
      user: { id: user_id }, return_url: "https://bridge.example/back", dossier_url: "https://acme.pipedrive.com/person/7",
    }.to_json).to_return_json(status: 201, body: { rdv_plan: { id: 5, user_id:, url: plan_url } })
  end

  def stub_person(**attrs)
    stub_request(:get, "#{PipedriveHelpers::API}/v1/persons/7")
      .to_return_json(body: { success: true, data: pipedrive_person(7, **attrs) })
  end

  def usager(id, first_name, last_name, email: nil)
    { id:, first_name:, last_name:, email:, phone_number: nil, phone_number_formatted: nil }
  end

  it "opens an RDV plan for a person transferred already" do
    create(:imported_usager, account:, provider_person_id: "7", rdvsp_user_id: 99)
    create_plan = stub_rdv_plan(99)

    expect(result).to be_success
    expect(result.url).to eq(plan_url)
    expect(create_plan).to have_been_requested
  end

  context "when the person isn't transferred yet" do
    before do
      create(:usager_import, account:, rdvsp_organisation_id: 41, state: "done", finished_at: 2.days.ago)
      create(:usager_import, account:, rdvsp_organisation_id: 42, state: "done", finished_at: 1.day.ago)
      create(:usager_import, account:, rdvsp_organisation_id: 43, state: "failed", finished_at: 1.hour.ago)
    end

    it "uses the usager of the last import's organisation with the same e-mail, and records it" do
      stub_person(email: [{ value: "ada@example.fr", primary: true }])
      stub_rdvsp_organisation_users(42, [usager(98, "Ada", "King", email: "ADA@example.fr")])
      stub_rdv_plan(98)

      expect(result.url).to eq(plan_url)
      expect(account.imported_usagers.sole)
        .to have_attributes(provider_person_id: "7", rdvsp_user_id: 98, rdvsp_organisation_id: 42)
    end

    it "creates the usager when the organisation has none like them" do
      stub_person
      stub_rdvsp_organisation_users(42, [usager(98, "Grace", "Hopper")])
      create_user = stub_request(:post, "#{rdvsp_url}/api/v1/users")
        .with(body: hash_including("first_name" => "Ada", "organisation_ids" => [42]))
        .to_return_json(body: { user: { id: 99 } })
      stub_rdv_plan(99)

      expect(result.url).to eq(plan_url)
      expect(create_user).to have_been_requested
      expect(account.imported_usagers.sole).to have_attributes(provider_person_id: "7", rdvsp_user_id: 99)
    end

    it "stops at a usager with the same name only: it may be someone else" do
      stub_person
      stub_rdvsp_organisation_users(42, [usager(98, "ada", "LOVELACE", email: "other@example.fr")])

      expect(result).to be_failure
      expect(result.reason).to eq(:homonym)
      expect(account.imported_usagers).to be_empty
    end

    it "stops when Pipedrive lacks the first or last name, or RDV-SP refuses the usager" do
      stub_person(last_name: " ")
      expect(result.reason).to eq(:incomplete_name)

      stub_person
      stub_rdvsp_organisation_users(42, [])
      stub_request(:post, "#{rdvsp_url}/api/v1/users")
        .to_return_json(status: 422, body: { errors: { birth_date: [{ error: "invalid" }] } })
      expect(described_class.call(account:, person_id: "7", return_url: "https://bridge.example/back").reason)
        .to eq(:rejected)
    end

    it "stops when Pipedrive doesn't know the person" do
      stub_request(:get, "#{PipedriveHelpers::API}/v1/persons/7").to_return(status: 404)

      expect(result.reason).to eq(:unknown_person)
    end
  end

  it "stops when no import chose an organisation yet" do
    expect(result.reason).to eq(:no_organisation)
  end

  it "stops when no agent authorized the bridge, or the authorization is lost" do
    account.rdvsp_authorization.update!(lost_at: Time.current)
    expect(result.reason).to eq(:no_authorization)

    account.rdvsp_authorization.destroy!
    expect(described_class.call(account: account.reload, person_id: "7", return_url: "x").reason)
      .to eq(:no_authorization)
  end
end
