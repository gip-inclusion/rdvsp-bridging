class AlertMailer < ApplicationMailer
  def account_failing(account)
    @account = account
    mail(to: [ENV["ALERT_EMAIL"], account.alert_email].compact_blank.uniq,
         subject: "[RDV Service Public] La synchronisation avec #{account.provider.capitalize} est interrompue")
  end
end
