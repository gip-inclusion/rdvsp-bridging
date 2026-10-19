class RefreshAccountJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_concurrency_rule(label: -> { "RefreshAccountJob-#{arguments.first.id}" }, apply_label: true, total_limit: 1)

  def perform(account)
    Providers.refresh_if_stale(account)
  end
end
