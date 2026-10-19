require "rails_helper"

RSpec.describe Pipedrive::RefreshAccount do
  let(:account) { create(:account, refresh_cursor: 10.minutes.ago) }
  let!(:alice) { create(:connection, account:, provider_user_id: "1") }
  let!(:bob) { create(:connection, account:, provider_user_id: "2") }

  it "applies updated activities to their owner's connection, and moves reassigned ones" do
    alice.upsert_busy_block!("10", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)
    stub_pipedrive_activities([pipedrive_activity(id: 10, owner_id: 2), pipedrive_activity(id: 11, owner_id: 1)])

    expect(described_class.call(account:)).to be_success

    expect(alice.busy_blocks.live.pluck(:provider_object_id)).to eq(["11"])
    expect(bob.busy_blocks.live.pluck(:provider_object_id)).to eq(["10"])
    expect(account.reload.refreshed_at).to be_within(5.seconds).of(Time.current)
  end

  it "asks Pipedrive for changes since the cursor, with an overlap" do
    since = (account.refresh_cursor - 2.minutes).utc.iso8601
    request = stub_pipedrive_activities([], query: hash_including("updated_since" => since))

    described_class.call(account:)

    expect(request).to have_been_requested
  end

  it "records failures on the account" do
    stub_request(:get, %r{/api/v2/activities}).to_return(status: 401, body: "{}")

    expect(described_class.call(account:)).to be_failure
    expect(account.reload).to be_failing
  end
end
