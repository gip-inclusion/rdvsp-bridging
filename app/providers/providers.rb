# Entry points the provider-agnostic parts of the app (CalDAV server, jobs) use to reach a provider
module Providers
  REFRESH_INTERVAL = 60.seconds

  module_function

  def namespace_for(account) = account.provider.camelize.constantize

  def refresh_if_stale(account)
    return if account.refreshed_at&.after?(REFRESH_INTERVAL.ago)

    account.with_lock do
      namespace_for(account)::RefreshAccount.call(account:) unless account.refreshed_at&.after?(REFRESH_INTERVAL.ago)
    end
  end

  def rebuild(connection) = namespace_for(connection.account)::RebuildConnection.call(connection:)

  def push_rdv(rdv) = namespace_for(rdv.connection.account)::PushRdv.call(rdv:)
end
