module RdvspHelpers
  RDVSP_URL = "https://rdv.example.fr".freeze

  def rdvsp_url = RDVSP_URL

  def stub_rdvsp_token(access_token: "new-access", refresh_token: "new-refresh", expires_in: 7200)
    stub_request(:post, "#{RDVSP_URL}/oauth/token")
      .to_return_json(body: { access_token:, refresh_token:, expires_in:, token_type: "Bearer" })
  end

  def stub_rdvsp_me(id: 1001, email: "agent@example.fr")
    stub_request(:get, "#{RDVSP_URL}/api/v1/agents/me").to_return_json(body: { agent: { id:, email: } })
  end

  def stub_rdvsp_organisations(organisations)
    stub_request(:get, "#{RDVSP_URL}/api/v1/organisations").with(query: hash_including({}))
      .to_return_json(body: { organisations:, meta: { next_page: nil } })
  end

  def stub_rdvsp_organisation_users(organisation_id, users)
    stub_request(:get, "#{RDVSP_URL}/api/v1/organisations/#{organisation_id}/users").with(query: hash_including({}))
      .to_return_json(body: { users:, meta: { next_page: nil } })
  end
end

RSpec.configure do |config|
  config.include RdvspHelpers
  config.around(:each, :rdvsp) do |example|
    names = %w[RDVSP_URL RDVSP_OAUTH_CLIENT_ID RDVSP_OAUTH_CLIENT_SECRET]
    previous = ENV.values_at(*names)
    names.zip([RdvspHelpers::RDVSP_URL, "client-id", "client-secret"]).each { |name, value| ENV[name] = value }
    example.run
  ensure
    names.zip(previous).each { |name, value| ENV[name] = value }
  end
end
