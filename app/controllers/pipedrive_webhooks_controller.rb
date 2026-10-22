# Pipedrive notifies activity changes here. The payload is only a hint: we re-fetch the activity.
class PipedriveWebhooksController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  HTTP_AUTH_USER = "rdvsp-bridging".freeze

  # The account's webhook token comes as the basic auth password, checked before the body is parsed
  def create
    account = authenticate_with_http_basic { |_user, token| Account.find_by(webhook_token: token) }
    return head :unauthorized if account.nil?

    activity_id = params.dig(:meta, :entity_id) || params.dig(:data, :id) || params.dig(:previous, :id)
    SyncActivityJob.perform_later(account, activity_id.to_s) if activity_id.to_s.match?(/\A\d+\z/)
    head :ok
  end
end
