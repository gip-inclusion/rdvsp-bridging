require "rails_helper"

RSpec.describe "Pipedrive webhooks" do
  let(:account) { create(:account) }

  it "re-fetches the activity" do
    post "/webhooks/pipedrive/#{account.webhook_token}",
         params: { meta: { action: "delete", entity: "activity", entity_id: "12" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(SyncActivityJob).to have_been_enqueued.with(account, "12")
  end

  it "ignores unknown tokens" do
    post "/webhooks/pipedrive/nope", params: { meta: { entity_id: "12" } }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
