class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "rdvsp-bridges <ne-pas-repondre@inclusion.gouv.fr>")
  layout "mailer"
end
