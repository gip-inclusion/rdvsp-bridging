require "rails_helper"

RSpec.describe Pipedrive::RebuildConnection do
  let(:connection) { create(:connection, provider_user_id: "1") }

  it "replaces busy blocks with the owner's activities, following cursors" do
    connection.upsert_busy_block!("99", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    stub_request(:get, %r{/api/v2/activities}).with(query: hash_including("owner_id" => "1"))
      .to_return_json({ body: { data: [pipedrive_activity(id: 1, owner_id: 1)],
                                additional_data: { next_cursor: "abc" }, } },
                      { body: { data: [pipedrive_activity(id: 2, owner_id: 1, busy: false)],
                                additional_data: { next_cursor: nil }, } })

    expect(described_class.call(connection:).count).to eq(1)
    expect(connection.busy_blocks.live.pluck(:provider_object_id)).to eq(["1"])
    expect(connection.busy_blocks.deleted.pluck(:provider_object_id)).to eq(["99"])
  end
end
