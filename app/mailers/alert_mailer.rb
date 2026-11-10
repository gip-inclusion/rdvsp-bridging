class AlertMailer < ApplicationMailer
  def account_failing(account)
    @account = account
    mail(to: [ENV["ALERT_EMAIL"], account.alert_email].compact_blank.uniq,
         subject: "[RDV Service Public] La synchronisation avec #{account.provider.capitalize} est interrompue")
  end

  # For us only: the partner can't do anything about it
  def connections_silent(connections)
    @connections = connections
    mail(to: ENV["ALERT_EMAIL"],
         subject: "[rdvsp-bridging] RDV Service Public ne consulte plus #{connections.size} agenda(s)")
  end
end
