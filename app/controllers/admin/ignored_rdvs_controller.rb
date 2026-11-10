# Ignoring after the fact the RDVs first received before a cut-off (Paris time), with a preview
class Admin::IgnoredRdvsController < Admin::BaseController
  PARIS = "Europe/Paris".freeze

  before_action { @connection = Connection.find(params.expect(:connection_id)) }

  def new
    @before = params[:before].present? ? parse_cutoff : default_cutoff
    @rdvs = candidates.order(:created_at)
  end

  def create
    @before = parse_cutoff
    count = Rdvs::Ignore.call(rdvs: candidates).count
    redirect_to admin_connection_path(@connection),
                notice: "#{count} RDV ignorés ; leurs activités sont en cours de suppression."
  end

  private

  def candidates = @connection.rdvs.where(ignored_at: nil, created_at: ...@before)

  def parse_cutoff
    Time.find_zone(PARIS).parse(params.expect(:before)) || raise(ActionController::BadRequest, "unreadable cut-off")
  rescue ArgumentError
    raise ActionController::BadRequest, "unreadable cut-off"
  end

  # The end of the last start-up window, or a quiet minute after the first RDV when no connection test was recorded
  def default_cutoff
    cutoff = @connection.baseline_until ||
             @connection.rdvs.minimum(:created_at)&.+(Connection::BASELINE_QUIET) ||
             Time.current
    cutoff.change(usec: 0)
  end
end
