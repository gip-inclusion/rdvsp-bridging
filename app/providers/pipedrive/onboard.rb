module Pipedrive
  # Creates or updates the account of a Pipedrive company from an admin API token: checks the token, creates the
  # "RDV Service Public" activity type and subscribes to activity webhooks when the bridge is publicly reachable.
  class Onboard < BaseService
    RDV_ACTIVITY_TYPE_NAME = "RDV Service Public".freeze

    def initialize(api_token:, alert_email: nil, base_url: ENV["BRIDGE_BASE_URL"])
      @api_token = api_token.to_s.strip
      @alert_email = alert_email
      @base_url = base_url
    end

    def call
      me = client.me
      account = Account.find_or_initialize_by(provider: "pipedrive", provider_company_id: me["company_id"].to_s)
      account.assign_attributes(name: me["company_name"], provider_company_domain: me["company_domain"],
                                api_token: @api_token, alert_email: @alert_email.presence || account.alert_email)
      account.rdv_activity_type_key = rdv_activity_type_key
      save_record!(account)
      subscribe_to_webhooks(account)
      result.account = account
    rescue Pipedrive::Error => e
      fail!(e.message)
    end

    private

    def client = @client ||= Client.new(@api_token)

    def rdv_activity_type_key
      existing = client.activity_types.find { it["name"] == RDV_ACTIVITY_TYPE_NAME && it["active_flag"] }
      (existing || client.create_activity_type(name: RDV_ACTIVITY_TYPE_NAME, icon_key: "calendar"))["key_string"]
    end

    def subscribe_to_webhooks(account)
      return unless @base_url.to_s.start_with?("https://")

      url = "#{@base_url.delete_suffix('/')}/webhooks/pipedrive/#{account.webhook_token}"
      webhook = client.webhooks.find { it["subscription_url"] == url } ||
                client.create_webhook(subscription_url: url, event_action: "*", event_object: "activity",
                                      version: "2.0")
      account.update!(provider_webhook_id: webhook["id"].to_s)
    end
  end
end
