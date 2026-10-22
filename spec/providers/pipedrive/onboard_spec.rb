require "rails_helper"

RSpec.describe Pipedrive::Onboard do
  subject(:result) { described_class.call(api_token: "admin-token", base_url: "https://bridge.example") }

  let(:api) { PipedriveHelpers::API }
  let(:account) { Account.last }

  before do
    me = { company_id: 7, company_name: "Entreprise", company_domain: "entreprise" }
    types = [{ name: "RDV Service Public", active_flag: true, key_string: "rdv_sp" }]
    webhooks = [
      { id: 1, subscription_url: "https://bridge.example/webhooks/pipedrive/old-token" },
      { id: 2, subscription_url: "https://bridge.example/webhooks/pipedrive" },
      { id: 3, subscription_url: "https://other-bridge.example/webhooks/pipedrive" },
    ]
    stub_request(:get, "#{api}/v1/users/me").to_return_json(body: { data: me })
    stub_request(:get, "#{api}/v1/activityTypes").to_return_json(body: { data: types })
    stub_request(:get, "#{api}/v1/webhooks").to_return_json(body: { data: webhooks })
    stub_request(:delete, %r{#{api}/v1/webhooks/\d+}).to_return_json(body: { data: { id: 1 } })
    stub_request(:post, "#{api}/v1/webhooks").to_return_json(body: { data: { id: 4 } })
  end

  it "subscribes to activity webhooks with the account's token as basic auth password" do
    expect(result).to be_success
    expected = { subscription_url: "https://bridge.example/webhooks/pipedrive", event_action: "*",
                 event_object: "activity", version: "2.0", http_auth_user: "rdvsp-bridging",
                 http_auth_password: account.webhook_token, }
    expect(WebMock).to have_requested(:post, "#{api}/v1/webhooks").with(body: expected)
    expect(account.provider_webhook_id).to eq("4")
  end

  it "replaces this bridge's previous webhooks, keeping other bridges' ones" do
    result

    expect(WebMock).to have_requested(:delete, "#{api}/v1/webhooks/1")
    expect(WebMock).to have_requested(:delete, "#{api}/v1/webhooks/2")
    expect(WebMock).not_to have_requested(:delete, "#{api}/v1/webhooks/3")
  end
end
