require "rails_helper"

RSpec.describe "Pipedrive webhooks" do
  let(:account) { create(:account) }
  let(:auth) { ActionController::HttpAuthentication::Basic.encode_credentials("rdvsp-bridging", account.webhook_token) }

  it "re-fetches the activity" do
    post "/webhooks/pipedrive", params: { meta: { action: "delete", entity: "activity", entity_id: "12" } },
                                headers: { "Authorization" => auth }, as: :json

    expect(response).to have_http_status(:ok)
    expect(SyncActivityJob).to have_been_enqueued.with(account, "12")
  end

  it "keeps the activity contents out of the logs" do
    params = { meta: { entity_id: "12" }, data: { subject: "Jeanne" }, previous: { note: "06" } }
    post "/webhooks/pipedrive", params:, headers: { "Authorization" => auth }, as: :json

    expect(request.filtered_parameters).to include("meta" => { "entity_id" => "12" }, "data" => "[FILTERED]",
                                                   "previous" => "[FILTERED]")
    expect(request.filtered_parameters.to_s).not_to include("Jeanne", "06")
  end

  it "ignores unknown tokens" do
    wrong = ActionController::HttpAuthentication::Basic.encode_credentials("rdvsp-bridging", "nope")
    post "/webhooks/pipedrive", params: { meta: { entity_id: "12" } }, headers: { "Authorization" => wrong }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(SyncActivityJob).not_to have_been_enqueued
  end

  it "checks the token before parsing the body" do
    post "/webhooks/pipedrive", params: "{not json", headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "no longer accepts the token in the URL" do
    post "/webhooks/pipedrive/#{account.webhook_token}", params: { meta: { entity_id: "12" } }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
