class RebuildConnectionJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_concurrency_rule(label: lambda {
    "RebuildConnectionJob-#{arguments.first.id}"
  }, apply_label: true, total_limit: 1)

  def perform(connection)
    Providers.rebuild(connection) unless connection.disabled_at?
  end
end
