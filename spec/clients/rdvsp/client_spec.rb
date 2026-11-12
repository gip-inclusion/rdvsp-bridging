require "rails_helper"

RSpec.describe Rdvsp::Client, :rdvsp do
  let(:authorization) { create(:rdvsp_authorization, access_token: "access", expires_at: 1.hour.from_now) }
  let(:client) { described_class.new(authorization) }

  it "calls the API as the agent who authorized the bridge" do
    me = stub_rdvsp_me(id: 7, email: "agent@example.fr").with(headers: { "Authorization" => "Bearer access" })

    expect(client.me).to include("id" => 7, "email" => "agent@example.fr")
    expect(me).to have_been_requested
  end

  it "refreshes the token once when RDV-SP refuses it, then gives up" do
    stub_request(:get, "#{rdvsp_url}/api/v1/agents/me").with(headers: { "Authorization" => "Bearer access" })
      .to_return(status: 401)
    stub_rdvsp_token(access_token: "new-access")
    stub_rdvsp_me.with(headers: { "Authorization" => "Bearer new-access" })

    expect(client.me).to include("id" => 1001)

    stub_request(:get, "#{rdvsp_url}/api/v1/agents/me").to_return(status: 401)
    expect { client.me }.to raise_error(Rdvsp::AuthenticationError)
  end

  it "follows the pages of an organisation's usagers" do
    path = "#{rdvsp_url}/api/v1/organisations/42/users"
    stub_request(:get, path).with(query: { page: "1" })
      .to_return_json(body: { users: [{ id: 1 }, { id: 2 }], meta: { next_page: 2 } })
    stub_request(:get, path).with(query: { page: "2" })
      .to_return_json(body: { users: [{ id: 3 }], meta: { next_page: nil } })

    expect(client.enum_for(:each_organisation_user, 42).pluck("id")).to eq([1, 2, 3])
  end

  it "creates a usager" do
    attributes = { first_name: "Ada", last_name: "Lovelace", organisation_ids: [42] }
    create_user = stub_request(:post, "#{rdvsp_url}/api/v1/users").with(body: attributes.to_json)
      .to_return_json(status: 200, body: { user: { id: 99 } })

    expect(client.create_user(attributes)).to include("id" => 99)
    expect(create_user).to have_been_requested
  end

  it "reports a refused usager by attribute and error code, never by value" do
    stub_request(:post, "#{rdvsp_url}/api/v1/users").to_return_json(
      status: 422,
      body: { errors: { email: [{ error: "invalid", value: "ada@" }],
                        "external_references.external_id": [{ error: "taken", value: "12" }], },
              error_messages: ["email invalide (ada@)"], }
    )

    expect { client.create_user({}) }.to raise_error(Rdvsp::UnprocessableError) { |error|
      expect(error.codes).to eq("email" => ["invalid"], "external_references.external_id" => ["taken"])
      expect(error.message).not_to include("ada@")
    }
  end

  it "raises a plain error on other failures" do
    stub_request(:get, "#{rdvsp_url}/api/v1/organisations").with(query: hash_including({})).to_return(status: 403)

    expect { client.organisations }.to raise_error(Rdvsp::Error, /403/)
  end
end
