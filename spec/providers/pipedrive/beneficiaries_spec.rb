require "rails_helper"

RSpec.describe Pipedrive::Beneficiaries do
  let(:client) { Pipedrive::Client.new("token") }
  let(:beneficiaries) do
    described_class.new(client, field_key: "abc123", option_id: "34", active_since: Date.new(2025, 1, 1))
  end

  it "keeps the persons with the option, across pages" do
    stub_pipedrive_persons([pipedrive_person(1), pipedrive_person(2, abc123: "12")],
                           [pipedrive_person(3, abc123: "34")])

    expect(beneficiaries.map(&:id)).to eq(%w[1 3])
  end

  it "keeps the persons active since the date: an activity since, an upcoming one, or created since" do
    stub_pipedrive_persons([
                             pipedrive_person(1, last_activity_date: "2024-12-31"),
                             pipedrive_person(2, last_activity_date: nil, next_activity_date: "2027-01-10"),
                             pipedrive_person(3, last_activity_date: nil, add_time: "2025-01-01 08:00:00"),
                             pipedrive_person(4, last_activity_date: nil),
                           ])

    expect(beneficiaries.map(&:id)).to eq(%w[2 3])
  end

  it "reads the names and the primary e-mail and phone, or the first ones" do
    emails = [{ value: "a@example.fr", primary: false }, { value: "b@example.fr", primary: true }]
    stub_pipedrive_persons([pipedrive_person(1, first_name: " Ada ", last_name: nil, email: emails,
                                                phone: [{ value: " 06 12 34 56 78 ", primary: false }])])

    expect(beneficiaries.first).to have_attributes(id: "1", first_name: "Ada", last_name: nil, email: "b@example.fr",
                                                   phone: "06 12 34 56 78")
  end

  it "lists the options of the person fields that can mark a beneficiary" do
    stub_request(:get, "#{PipedriveHelpers::API}/v1/personFields").with(query: hash_including({}))
      .to_return_json(body: { success: true, data: [
                        { key: "abc123", name: "Type", field_type: "set", options: [{ id: 34, label: "Accompagnée" }] },
                        { key: "def456", name: "Statut", field_type: "enum", options: [{ id: 1, label: "Actif" }] },
                        { key: "name", name: "Nom", field_type: "varchar" },
                      ], })

    expect(described_class.options(client)).to eq([["Type → Accompagnée", "abc123:34"], ["Statut → Actif", "def456:1"]])
  end
end
