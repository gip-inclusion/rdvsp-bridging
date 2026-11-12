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

  USAGER_IMPORT_STATES = { "queued" => "en attente", "running" => "en cours", "done" => "terminé",
                           "failed" => "en échec", }.freeze
  USAGER_IMPORT_COUNTS = {
    "created" => %w[créé créés], "rejected" => %w[refusé refusés],
    "created_without_contact" => ["créé sans e-mail ni téléphone", "créés sans e-mail ni téléphone"],
    "already_in_rdvsp" => ["déjà présent ou en double", "déjà présents ou en double"],
    "already_imported" => ["déjà importé", "déjà importés"],
    "incomplete_name" => ["sans prénom ou nom", "sans prénom ou nom"],
  }.freeze

  def usager_import_state(usager_import)
    state = USAGER_IMPORT_STATES.fetch(usager_import.state)
    usager_import.error ? "#{state} : #{usager_import.error}" : state
  end

  # "12 créés, 1 refusé (birth_date : 1)": counts and attribute names only
  def usager_import_summary(usager_import)
    parts = USAGER_IMPORT_COUNTS.filter_map do |key, (singular, plural)|
      count = usager_import.counts[key].to_i
      "#{count} #{count > 1 ? plural : singular}" if count.positive?
    end
    rejections = usager_import.rejections.map { |attributes, count| "#{attributes} : #{count}" }
    parts << "motifs des refus : #{rejections.join(', ')}" if rejections.any?
    parts.join(", ").presence || "—"
  end
end
