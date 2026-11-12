require "rails_helper"

RSpec.describe UsagerImports::Plan, :rdvsp do
  let(:account) { create(:account) }
  let(:result) do
    described_class.call(account:, organisation_id: 42, field_key: "abc123", option_id: "34",
                         active_since: Date.new(2025, 1, 1))
  end

  before { create(:rdvsp_authorization, account:) }

  def usager(first_name, last_name, email: nil, phone_number_formatted: nil)
    { id: rand(1000), first_name:, last_name:, email:, phone_number: nil, phone_number_formatted: }
  end

  it "sorts the beneficiaries, and counts them without naming them" do
    create(:imported_usager, account:, provider_person_id: "1")
    stub_rdvsp_organisation_users(42, [
                                    usager("Grace", "Hopper", email: "Grace@Example.fr"),
                                    usager("Alan", "Turing", phone_number_formatted: "+33612345678"),
                                    usager("Hélène", "Dupont"),
                                  ])
    stub_pipedrive_persons([
                             pipedrive_person(1),
                             pipedrive_person(2, first_name: nil),
                             pipedrive_person(3, email: [{ value: "grace@example.fr", primary: true }]),
                             pipedrive_person(4, phone: [{ value: "06 12 34 56 78", primary: true }]),
                             pipedrive_person(5, first_name: "helene", last_name: "DUPONT"),
                             pipedrive_person(6, first_name: "Katherine", last_name: "Johnson",
                                                 email: [{ value: "kj@example.fr", primary: true }]),
                             pipedrive_person(7, first_name: "Kathy", last_name: "J",
                                                 email: [{ value: "KJ@example.fr", primary: true }]),
                             pipedrive_person(8, abc123: "12"),
                           ])

    expect(result.counts).to eq("selected" => 7, "already_imported" => 1, "incomplete_name" => 1,
                                "already_in_rdvsp" => 4, "to_create" => 1)
    expect(result.to_create.map(&:id)).to eq(%w[6])
  end
end
