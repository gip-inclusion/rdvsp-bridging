# The page where an agent gets the CalDAV credentials to paste in RDV-SP, from a link the team sent (docs/ui.md)
class CaldavSetupsController < ApplicationController
  include PublicMessages

  layout "public"

  before_action do
    @connection = Connection.find_by_token_for(:caldav_setup, params[:token])
    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe qui vous l’a envoyé.", :not_found) \
      unless @connection
  end

  def show; end

  # A new password, shown once: it spends the link, and replaces any password RDV-SP already uses
  def create
    @password = Connection.generate_password
    @connection.update!(password: @password)
    response.headers["Cache-Control"] = "no-store"
    render :show
  end
end
