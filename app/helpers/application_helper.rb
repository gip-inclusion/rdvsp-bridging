module ApplicationHelper
  def paris_time(time) = time && l(time.in_time_zone("Europe/Paris"), format: :seconds)

  def rdv_status(rdv)
    if rdv.ignored? then rdv.cancelled? ? "ignoré (annulé depuis)" : "ignoré"
    elsif rdv.state == "failed" then "en échec"
    elsif rdv.state == "pending" then "en attente"
    elsif rdv.cancelled? then "annulé"
    elsif rdv.provider_object_id then "transmis"
    else "transmis à sa prochaine modification dans RDV-SP"
    end
  end
end
