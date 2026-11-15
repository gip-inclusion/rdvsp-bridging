# Badges, French counts and copy fields of the admin pages (docs/ui.md)
module AdminHelper
  BADGE_TONES = {
    success: "bg-success-lighter text-success", info: "bg-info-lighter text-info",
    warning: "bg-warning-lighter text-warning", danger: "bg-danger-lighter text-danger",
    neutral: "bg-accent-03 text-primary",
  }.freeze
  USAGER_IMPORT_TONES = { "queued" => :warning, "running" => :info, "done" => :success, "failed" => :danger }.freeze

  def badge(text, tone, size: :sm)
    tag.span(text, class: "badge badge-#{size} rounded-pill #{BADGE_TONES.fetch(tone)}")
  end

  # "0 ignoré", "1 ignoré", "3 ignorés"
  def count_label(count, singular, plural = "#{singular}s") = "#{count} #{count > 1 ? plural : singular}"

  def account_source(account)
    return account.provider.capitalize unless account.provider == "pipedrive"

    "Pipedrive · #{account.provider_company_domain}.pipedrive.com"
  end

  def account_badge(account, size: :sm)
    return badge("OK", :success, size:) unless account.failing?

    badge("En erreur depuis le #{l(account.failing_since, format: :short)}", :danger, size:)
  end

  # From RDV-SP's last visit, and whether CheckHealthJob sent a silence alert since
  def connection_badge(connection, size: :sm)
    seen_at = connection.last_seen_at
    if seen_at.nil? then badge("RDV-SP jamais venu", :warning, size:)
    elsif connection.silence_alerted_at&.after?(seen_at) then badge("RDV-SP ne passe plus", :danger, size:)
    else badge("Synchronisée", :success, size:)
    end
  end

  def rdv_badge(rdv)
    tone = if rdv.ignored? then :info
           elsif rdv.state == "failed" then :danger
           elsif rdv.state == "pending" then :warning
           elsif rdv.cancelled? then :neutral
           else :success
           end
    badge(rdv_status(rdv).upcase_first, tone)
  end

  def usager_import_badge(usager_import)
    state = usager_import.state
    badge(ApplicationHelper::USAGER_IMPORT_STATES.fetch(state).upcase_first, USAGER_IMPORT_TONES.fetch(state))
  end

  # A read-only field and its "Copier" button (app/assets/javascripts/copy.js); a <label for> names it
  def copy_field(id, value)
    tag.div(class: "input-group") do
      tag.input(id:, value:, readonly: true, class: "form-control pont-code") +
        tag.button(type: "button", class: "btn btn-outline-primary btn-ico-only", data: { copy_target: id },
                   aria: { label: "Copier" }) { tag.i(class: "ri-file-copy-line", aria: { hidden: true }) }
    end
  end
end
