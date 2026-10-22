# Pipedrive notifies activity changes here. The payload is only a hint: we re-fetch the activity.
class PipedriveWebhooksController < ActionController::API
  def create
    # Read from the path: `params` would parse the body before the token is checked
    account = Account.find_by(webhook_token: request.path_parameters[:token].to_s)
    return head :not_found if account.nil?

    activity_id = params.dig(:meta, :entity_id) || params.dig(:data, :id) || params.dig(:previous, :id)
    SyncActivityJob.perform_later(account, activity_id.to_s) if activity_id.to_s.match?(/\A\d+\z/)
    head :ok
  end
end
