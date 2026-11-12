class ImportUsagersJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_concurrency_rule(label: -> { "ImportUsagersJob-#{arguments.first.account_id}" }, apply_label: true,
                            perform_limit: 1)

  retry_on Rdvsp::Error, Pipedrive::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.fail!(error)
  end
  discard_on Rdvsp::AuthenticationError, Pipedrive::AuthenticationError do |job, error|
    job.arguments.first.fail!(error)
  end

  def perform(usager_import)
    UsagerImports::Run.call(usager_import:)
  end
end
