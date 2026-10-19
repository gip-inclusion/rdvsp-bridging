require "rails_helper"

RSpec.describe Pipedrive::PushRdv do
  let(:account) { create(:account) }
  let(:connection) { create(:connection, account:, provider_user_id: "5") }
  let(:rdv) { create(:rdv, connection:) }
  let(:api) { PipedriveHelpers::API }

  it "creates the activity, remembers it and forgets the payload" do
    stub_request(:post, "#{api}/api/v2/activities").to_return_json(body: { data: { id: 77 } })

    described_class.call(rdv:)

    expect(rdv.reload).to have_attributes(provider_object_id: "77", state: "synced", payload: nil)
  end

  it "updates the existing activity" do
    rdv.update!(provider_object_id: "77")
    request = stub_request(:patch, "#{api}/api/v2/activities/77").to_return_json(body: { data: { id: 77 } })

    described_class.call(rdv:)

    expect(request).to have_been_requested
  end

  it "recreates the activity when the partner deleted it in Pipedrive" do
    rdv.update!(provider_object_id: "77")
    stub_request(:patch, "#{api}/api/v2/activities/77").to_return(status: 404, body: "{}")
    stub_request(:post, "#{api}/api/v2/activities").to_return_json(body: { data: { id: 78 } })

    described_class.call(rdv:)

    expect(rdv.reload.provider_object_id).to eq("78")
  end

  it "deletes the activity of a cancelled RDV" do
    rdv.update!(provider_object_id: "77", cancelled_at: Time.current)
    request = stub_request(:delete, "#{api}/api/v2/activities/77").to_return_json(body: { data: { id: 77 } })

    described_class.call(rdv:)

    expect(request).to have_been_requested
    expect(rdv.reload.state).to eq("synced")
  end

  it "marks the RDV as failed and raises so the job retries" do
    stub_request(:post, "#{api}/api/v2/activities").to_return(status: 500, body: "{}")

    expect { described_class.call(rdv:) }.to raise_error(Pipedrive::Error)
    expect(rdv.reload.state).to eq("failed")
  end

  context "when linking persons" do
    before { account.update!(usager_details: true, link_persons: true) }

    it "links an existing person matching the usager's name exactly once" do
      rdv.update!(payload: { "summary" => "Jeanne Dupont - Accueil" })
      stub_request(:get, "#{api}/api/v2/persons/search").with(query: hash_including("term" => "Jeanne Dupont"))
        .to_return_json(body: { data: { items: [{ item: { id: 3 } }] } })
      create_request = stub_request(:post, "#{api}/api/v2/activities")
        .with(body: hash_including("participants" => [{ "person_id" => 3, "primary" => true }]))
        .to_return_json(body: { data: { id: 77 } })

      described_class.call(rdv:)

      expect(create_request).to have_been_requested
      expect(rdv.reload.provider_person_id).to eq("3")
    end
  end
end
