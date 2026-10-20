class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "rdvsp-bridging <ne-pas-repondre@inclusion.gouv.fr>")
  layout "mailer"
end
