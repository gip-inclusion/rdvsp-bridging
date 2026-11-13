# The bridge's private app in Pipedrive: the "Prendre RDV" link action on a person, the way back from RDV-SP, and the
# installation
class PipedriveAppController < ApplicationController
  include PublicMessages

  layout "public"

  FAILURES = {
    no_authorization: ["Pont RDV n’a pas accès à RDV Service Public",
                       "Demandez à l’équipe de Pont RDV un lien pour l’autoriser.", :forbidden,],
    no_organisation: ["Pont RDV ne sait pas dans quelle organisation créer cette personne",
                      "Demandez à l’équipe de Pont RDV de la choisir.",
                      :unprocessable_content,],
    unknown_person: ["Pipedrive ne trouve pas cette personne", "Rechargez sa fiche dans Pipedrive.", :not_found],
    incomplete_name: ["Il manque le prénom ou le nom de cette personne",
                      "RDV Service Public demande les deux : complétez sa fiche dans Pipedrive, puis cliquez à " \
                      "nouveau sur « Prendre RDV ».", :unprocessable_content,],
    homonym: ["Une autre personne porte ce nom dans RDV Service Public",
              "Elle n’a ni le même e-mail ni le même téléphone : ce n’est peut-être pas la même. Prenez le " \
              "rendez-vous directement dans RDV Service Public.", :unprocessable_content,],
    rejected: ["RDV Service Public a refusé cette personne",
               "Vérifiez sa fiche dans Pipedrive, ou prenez le rendez-vous directement dans RDV Service Public.",
               :unprocessable_content,],
  }.freeze

  before_action { head(:not_found) unless Pipedrive::App.configured? && Rdvsp::Oauth.configured? }

  def rdv_plan
    claims = Pipedrive::App.claims(params[:token])
    account = Account.find_by(provider: "pipedrive", provider_company_id: claims["companyId"].to_s)
    unless account
      return message("Pont RDV n’est pas activé pour votre entreprise", "Contactez l’équipe de Pont RDV.", :not_found)
    end

    person_ids = params[:selectedIds].to_s.split(",")
    unless params[:resource] == "person" && person_ids.one? && person_ids.first.match?(/\A\d+\z/)
      return message("Choisissez une personne", "Le bouton « Prendre RDV » s’utilise depuis la fiche d’une personne.",
                     :bad_request)
    end

    start(account, person_ids.first)
  rescue Pipedrive::App::InvalidToken
    message("Ce lien ne vient pas de Pipedrive",
            "Ouvrez la fiche de la personne dans Pipedrive et cliquez à nouveau sur « Prendre RDV ».", :unauthorized)
  end

  # The "Retour" link RDV-SP shows on the plan and the RDV: RDV-SP only accepts the bridge's host there
  def back
    account_id, person_id = verifier.verified(params[:token])
    url = account_id && Account.find_by(id: account_id)&.provider_person_url(person_id)
    return message("Ce lien n’est plus valable", "Retrouvez la personne dans Pipedrive.", :not_found) unless url

    redirect_to url, allow_other_host: true
  end

  def callback
    if params[:error].present?
      return message("Pont RDV n’a pas été installé", "Rien n’a été modifié dans Pipedrive.")
    end

    Pipedrive::App.complete_installation(code: params[:code].to_s, redirect_uri: callback_url)
    message("Pont RDV est installé", "Le bouton « Prendre RDV » apparaît sur la fiche des personnes dans Pipedrive.")
  rescue Pipedrive::Error => e
    Rails.logger.warn("Pipedrive app installation failed: #{e.message}")
    message("Pipedrive n’a pas répondu comme prévu", "Recommencez l’installation.", :bad_gateway)
  end

  private

  def start(account, person_id)
    back_path = pipedrive_back_path(token: verifier.generate([account.id, person_id]))
    result = RdvPlans::Start.call(account:, person_id:, return_url: "#{Rails.configuration.x.base_url}#{back_path}")
    return redirect_to(result.url, allow_other_host: true) if result.success?

    message(*FAILURES.fetch(result.reason))
  rescue Rdvsp::Error, Pipedrive::Error => e
    Rails.logger.warn("RDV plan for person #{person_id} of account #{account.id} failed: #{e.message}")
    message("RDV Service Public ou Pipedrive n’a pas répondu comme prévu", "Réessayez dans un instant.", :bad_gateway)
  end

  def verifier = Rails.application.message_verifier(:pipedrive_person)

  def callback_url = "#{Rails.configuration.x.base_url}#{pipedrive_app_callback_path}"
end
