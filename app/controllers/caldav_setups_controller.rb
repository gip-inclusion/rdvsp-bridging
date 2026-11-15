# The page where an agent gets the CalDAV credentials to paste in RDV-SP, from a link the team sent (docs/ui.md)
class CaldavSetupsController < ApplicationController
  include PublicMessages

  layout "public"

  before_action do
    @connection = Connection.find_by_caldav_link(params[:token])
    message("Ce lien n’est plus valable", "Demandez un nouveau lien à l’équipe qui vous l’a envoyé.", :not_found) \
      unless @connection
  end

  # Shows a password just generated once: reloading offers another one
  def show
    @password = flash[:password]
    response.headers["Cache-Control"] = "no-store" if @password
  end

  def create
    generated = @connection.use_caldav_link!
    redirect_to caldav_setup_path(params[:token]), flash: { password: generated }
  end
end
