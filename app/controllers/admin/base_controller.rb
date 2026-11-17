# The team signs in with HTTP Basic; a partner's admin reaches their account's pages through a partner link's session
# (docs/partner-links.md). Controllers stay closed to partners unless they call open_to_partners, and look records up
# through `accounts` and `connections`, so another account answers 404.
class Admin::BaseController < ApplicationController
  # Fails at boot in production when ADMIN_PASSWORD is missing (controllers are eager loaded)
  PASSWORD = Rails.env.local? ? ENV.fetch("ADMIN_PASSWORD", "admin") : ENV.fetch("ADMIN_PASSWORD")
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  # Before authentication, so that wrong passwords count too
  rate_limit to: 30, within: 1.minute, store: RATE_LIMIT_STORE
  before_action :authenticate
  before_action :refuse_partners
  layout "admin"

  helper_method :partner_link

  def self.open_to_partners(**) = skip_before_action(:refuse_partners, **)

  private

  def authenticate
    return http_basic_authenticate_or_request_with(name: "admin", password: PASSWORD) unless session[:partner_link_id]
    return if partner_link

    reset_session
    render "shared/message", layout: "public", status: :not_found,
                             locals: { title: "Ce lien n’est plus valable",
                                       text: "Demandez un nouveau lien à l’équipe de Pont RDV.", success: false, }
  end

  def refuse_partners
    raise ActiveRecord::RecordNotFound, "not open to partners" if partner_link
  end

  def partner_link
    return @partner_link if defined?(@partner_link)

    link = session[:partner_link_id] && PartnerLink.find_by(id: session[:partner_link_id])
    @partner_link = (link if link&.active?)
  end

  # The accounts this request may reach: the partner link's, or all of them for the team
  def accounts = partner_link ? Account.where(id: partner_link.account_id) : Account.all

  def connections = Connection.where(account: accounts)
end
