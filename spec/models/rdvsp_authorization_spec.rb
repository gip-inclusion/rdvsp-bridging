require "rails_helper"

RSpec.describe RdvspAuthorization, :rdvsp do
  let(:account) { create(:account) }

  it "encrypts the tokens and allows one authorization per account" do
    authorization = create(:rdvsp_authorization, account:, access_token: "access-1", refresh_token: "refresh-1")

    raw = described_class.connection.select_one("SELECT access_token, refresh_token FROM rdvsp_authorizations")
    expect(raw.values).not_to include("access-1", "refresh-1")
    expect(authorization.reload.access_token).to eq("access-1")
    expect(build(:rdvsp_authorization, account:)).not_to be_valid
  end

  it "keeps the account's authorization apart from its agents' ones, one per Pipedrive user" do
    import = create(:rdvsp_authorization, account:)
    agent = create(:rdvsp_authorization, account:, provider_user_id: "501")

    expect(account.reload.rdvsp_authorization).to eq(import)
    expect(account.rdvsp_agent_authorizations).to contain_exactly(agent)
    expect(build(:rdvsp_authorization, account:, provider_user_id: "501")).not_to be_valid
    expect(build(:rdvsp_authorization, account:, provider_user_id: "502")).to be_valid
  end

  it "stores an agent's authorization without touching the account's one" do
    import = create(:rdvsp_authorization, account:, agent_id: 77)
    stub_rdvsp_token(access_token: "agent-access")
    stub_rdvsp_me(id: 78, email: "lea@example.fr").with(headers: { "Authorization" => "Bearer agent-access" })

    described_class.authorize!(account:, provider_user_id: "501", code: "abc", redirect_uri: "https://bridge/cb")

    expect(account.reload.rdvsp_authorization).to eq(import)
    expect(account.rdvsp_agent_authorizations.sole)
      .to have_attributes(provider_user_id: "501", agent_id: 78, agent_email: "lea@example.fr")
  end

  it "keeps an agent's tokens when RDV-SP brings back another agent than the one of their connection" do
    create(:connection, account:, provider_user_id: "501", agent_email: " Lea@example.fr ")
    lea = create(:rdvsp_authorization, account:, provider_user_id: "501", agent_id: 78, access_token: "lea-access")
    stub_rdvsp_token(access_token: "paul-access", refresh_token: "paul-refresh")
    stub_rdvsp_me(id: 79, email: "paul@example.fr")
    stub_request(:post, "#{rdvsp_url}/oauth/revoke")

    expect { described_class.authorize!(account:, provider_user_id: "501", code: "abc", redirect_uri: "https://x/cb") }
      .to raise_error(described_class::OtherAgent)
    expect(WebMock).to have_requested(:post, "#{rdvsp_url}/oauth/revoke")
      .with(body: hash_including(token: "paul-refresh"))
    expect(lea.reload).to have_attributes(agent_id: 78, access_token: "lea-access")

    stub_rdvsp_me(id: 78, email: "lea@example.fr")
    described_class.authorize!(account:, provider_user_id: "501", code: "abc", redirect_uri: "https://x/cb")
    expect(lea.reload.access_token).to eq("paul-access")
  end

  it "goes away with its account, as do the account's imports" do
    create(:rdvsp_authorization, account:)
    create(:rdvsp_authorization, account:, provider_user_id: "501")
    usager_import = create(:usager_import, account:)
    create(:imported_usager, account:, usager_import:)

    expect { account.destroy! }.to change(described_class, :count).by(-2)
      .and change(UsagerImport, :count).by(-1).and change(ImportedUsager, :count).by(-1)
  end

  describe "#fresh_access_token" do
    let(:authorization) { create(:rdvsp_authorization, account:, expires_at:) }

    context "when the token is still valid for a while" do
      let(:expires_at) { 30.minutes.from_now }

      it "returns it without asking RDV-SP" do
        expect(authorization.fresh_access_token).to eq("rdvsp-access")
      end
    end

    context "when the token is about to expire" do
      let(:expires_at) { 30.seconds.from_now }

      it "refreshes it and keeps the new refresh token, which replaces the old one at RDV-SP" do
        stub_rdvsp_token.with(body: hash_including(grant_type: "refresh_token", refresh_token: "rdvsp-refresh"))

        expect(authorization.fresh_access_token).to eq("new-access")
        expect(authorization.reload).to have_attributes(refresh_token: "new-refresh", expires_at: be > 1.hour.from_now)
      end

      it "marks the authorization as lost when RDV-SP refuses the refresh" do
        stub_request(:post, "#{rdvsp_url}/oauth/token").to_return_json(status: 400, body: { error: "invalid_grant" })

        expect { authorization.fresh_access_token }.to raise_error(Rdvsp::AuthenticationError)
        expect(authorization.reload).to be_lost
        expect { authorization.fresh_access_token }.to raise_error(Rdvsp::AuthenticationError, /again/)
      end
    end
  end
end
