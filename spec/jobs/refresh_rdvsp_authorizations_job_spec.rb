require "rails_helper"

RSpec.describe RefreshRdvspAuthorizationsJob, :rdvsp do
  it "refreshes the tokens issued long ago, before RDV-SP deletes them for a newer one of the same agent" do
    idle = create(:rdvsp_authorization, refresh_token: "idle-refresh", expires_at: 21.days.ago)
    create(:rdvsp_authorization, refresh_token: "recent-refresh", expires_at: 2.days.ago)
    create(:rdvsp_authorization, refresh_token: "lost-refresh", expires_at: 40.days.ago, lost_at: 1.day.ago)
    refresh = stub_rdvsp_token.with(body: hash_including(grant_type: "refresh_token", refresh_token: "idle-refresh"))

    described_class.perform_now

    expect(refresh).to have_been_requested.once
    expect(WebMock).to have_requested(:post, "#{rdvsp_url}/oauth/token").once
    expect(idle.reload).to have_attributes(refresh_token: "new-refresh", expires_at: be > 1.hour.from_now)
  end

  it "goes on after a refused refresh, which marks that authorization lost" do
    refused = create(:rdvsp_authorization, refresh_token: "refused", expires_at: 25.days.ago)
    other = create(:rdvsp_authorization, refresh_token: "other", expires_at: 25.days.ago)
    stub_request(:post, "#{rdvsp_url}/oauth/token").with(body: hash_including(refresh_token: "refused"))
      .to_return_json(status: 400, body: { error: "invalid_grant" })
    stub_rdvsp_token.with(body: hash_including(refresh_token: "other"))

    described_class.perform_now

    expect(refused.reload).to be_lost
    expect(other.reload.refresh_token).to eq("new-refresh")
  end
end
