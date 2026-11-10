class Admin::RdvsController < Admin::BaseController
  # An RDV ignored by mistake (booked right after the connection test): ignored RDVs keep no content, so it is pushed
  # at RDV-SP's next PUT of it
  def release
    rdv = Rdv.find(params.expect(:id))
    rdv.update!(ignored_at: nil)
    redirect_to admin_connection_path(rdv.connection),
                notice: "Le RDV sera transmis à sa prochaine modification dans RDV-SP, ou au prochain " \
                        "enregistrement des paramètres CalDAV de l’agent."
  end
end
