class PushRdvJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_concurrency_rule(label: -> { "PushRdvJob-#{arguments.first.id}" }, apply_label: true, perform_limit: 1)

  retry_on Pipedrive::Error, wait: :polynomially_longer, attempts: 10

  def perform(rdv)
    Providers.push_rdv(rdv)
  end
end
