require "rails_helper"

RSpec.describe Pipedrive::App, :pipedrive_app do
  describe ".claims" do
    it "returns the user and company of a click signed with the app's client secret" do
      expect(described_class.claims(pipedrive_click_token(user_id: 7, company_id: 9)))
        .to include("userId" => 7, "companyId" => 9)
    end

    it "refuses a token signed with another secret, expired, unsigned or missing" do
      unsigned = JWT.encode({ userId: 7, companyId: 9 }, nil, "none")
      [pipedrive_click_token(secret: "other"), pipedrive_click_token(exp: 1.minute.ago.to_i), unsigned, nil, ""]
        .each { expect { described_class.claims(it) }.to raise_error(Pipedrive::App::InvalidToken) }
    end
  end

  describe ".complete_installation" do
    it "exchanges the code Pipedrive sent back to the callback" do
      exchange = stub_request(:post, "https://oauth.pipedrive.com/oauth/token")
        .with(basic_auth: [PipedriveHelpers::APP_CLIENT_ID, PipedriveHelpers::APP_CLIENT_SECRET],
              body: { grant_type: "authorization_code", code: "abc", redirect_uri: "https://bridge.example/cb" })
        .to_return_json(body: { access_token: "a", refresh_token: "r" })

      described_class.complete_installation(code: "abc", redirect_uri: "https://bridge.example/cb")

      expect(exchange).to have_been_requested
    end

    it "raises when Pipedrive refuses the code" do
      stub_request(:post, "https://oauth.pipedrive.com/oauth/token").to_return(status: 400, body: "{}")

      expect { described_class.complete_installation(code: "abc", redirect_uri: "https://bridge.example/cb") }
        .to raise_error(Pipedrive::Error, /400/)
    end
  end
end
