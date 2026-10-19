class RefreshAccountsJob < ApplicationJob
  def perform
    Account.joins(:connections).merge(Connection.active).distinct.find_each { RefreshAccountJob.perform_later(it) }
  end
end
