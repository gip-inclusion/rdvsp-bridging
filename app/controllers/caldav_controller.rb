# A minimal CalDAV server exposing one calendar per connection, shaped after the requests RDV-SP's CalDAV client makes
# (see CLAUDE.md). Busy blocks are read-only; RDVs PUT by RDV-SP are pushed to the provider asynchronously.
class CaldavController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  CONNECTION_TEST_PREFIX = "rdvsp-connection-test-".freeze
  DAV_HEADERS = {
    "DAV" => "1, 3, calendar-access",
    "Allow" => "OPTIONS, GET, HEAD, PUT, DELETE, PROPFIND, REPORT",
  }.freeze

  before_action :authenticate
  before_action { response.headers.merge!(DAV_HEADERS) }

  def home
    case request.method
    when "OPTIONS" then head :ok
    when "PROPFIND"
      multistatus = Caldav::Multistatus.new
      add_resource(multistatus, properties.home_href, properties.home)
      add_resource(multistatus, properties.calendar_href, properties.calendar) if depth == 1
      render_multistatus(multistatus)
    else head :method_not_allowed
    end
  end

  def calendar
    case request.method
    when "OPTIONS" then head :ok
    when "PROPFIND" then propfind_calendar
    when "REPORT" then report
    when "GET", "HEAD" then render plain: calendar_ics, content_type: "text/calendar"
    else head :method_not_allowed
    end
  end

  def event
    case request.method
    when "OPTIONS" then head :ok
    when "PUT" then put_event
    when "DELETE" then delete_event
    when "GET", "HEAD" then show_event
    when "PROPFIND" then propfind_event
    else head :method_not_allowed
    end
  end

  private

  attr_reader :connection

  def authenticate
    @connection = authenticate_with_http_basic { |username, password| Connection.authenticate(username, password) }
    return request_http_basic_authentication("rdvsp-bridges") if @connection.nil?
    return head :not_found if @connection.public_id != params[:public_id]

    @connection.touch_last_seen!
  end

  def properties
    @properties ||= Caldav::Properties.new(connection, base_path: request.script_name)
  end

  def request_body
    @request_body ||= Caldav::RequestBody.new(request.raw_post)
  end

  # PROPFIND without Depth means infinity, which we answer like Depth 1
  def depth = request.headers["Depth"].to_s == "0" ? 0 : 1

  def propfind_calendar
    multistatus = Caldav::Multistatus.new
    add_resource(multistatus, properties.calendar_href, properties.calendar)
    if depth == 1
      connection.busy_blocks.live.find_each do |block|
        add_resource(multistatus, properties.event_href(block.href_name), properties.event(etag: block.etag))
      end
    end
    render_multistatus(multistatus)
  end

  def propfind_event
    etag = busy_block&.etag || rdv&.etag
    return head :not_found if etag.nil?

    multistatus = Caldav::Multistatus.new
    add_resource(multistatus, properties.event_href(params[:name]), properties.event(etag:))
    render_multistatus(multistatus)
  end

  def report
    refresh_provider_data
    case request_body.root_name
    when "sync-collection" then sync_collection
    when "calendar-query" then calendar_query
    when "calendar-multiget" then calendar_multiget
    else head :bad_request
    end
  end

  def sync_collection
    changes = connection.changes_since(request_body.sync_token)
    multistatus = Caldav::Multistatus.new
    changes.updated.each { |block| add_busy_block(multistatus, block) }
    changes.deleted.each { |block| multistatus.add_not_found(properties.event_href(block.href_name)) }
    multistatus.sync_token = changes.token
    render_multistatus(multistatus)
  end

  def calendar_query
    range = request_body.time_range
    blocks = connection.busy_blocks.live.order(:starts_at)
    blocks = blocks.where(starts_at: ...range.end, ends_at: (range.begin + 1.second)..) if range
    multistatus = Caldav::Multistatus.new
    blocks.each { |block| add_busy_block(multistatus, block) }
    render_multistatus(multistatus)
  end

  def calendar_multiget
    multistatus = Caldav::Multistatus.new
    request_body.hrefs.each do |href|
      block = find_busy_block(href.split("/").last)
      block ? add_busy_block(multistatus, block) : multistatus.add_not_found(href)
    end
    render_multistatus(multistatus)
  end

  def put_event
    return created_connection_test if connection_test?

    result = Rdvs::Receive.call(connection:, href_name: params[:name], ics: request.raw_post)
    return head :bad_request if result.failure?

    response.headers["ETag"] = result.rdv.etag
    head(result.created ? :created : :no_content)
  end

  def delete_event
    return head :no_content if connection_test?

    result = Rdvs::Cancel.call(connection:, href_name: params[:name])
    head(result.success? ? :no_content : :not_found)
  end

  def show_event
    if busy_block
      response.headers["ETag"] = busy_block.etag
      render plain: Caldav::BusyBlockIcs.render(busy_block), content_type: "text/calendar"
    elsif rdv && !rdv.cancelled?
      response.headers["ETag"] = rdv.etag
      render plain: Caldav::RdvIcs.render(rdv), content_type: "text/calendar"
    else
      head :not_found
    end
  end

  def created_connection_test
    response.headers["ETag"] = %("#{SecureRandom.hex(8)}")
    head :created
  end

  def connection_test? = params.expect(:name).start_with?(CONNECTION_TEST_PREFIX)

  def busy_block
    return @busy_block if defined?(@busy_block)

    @busy_block = find_busy_block(params[:name])
  end

  def rdv
    return @rdv if defined?(@rdv)

    @rdv = connection.rdvs.find_by(href_name: params[:name])
  end

  def find_busy_block(href_name)
    id = BusyBlock.provider_object_id_from(href_name)
    id && connection.busy_blocks.live.find_by(provider_object_id: id)
  end

  def add_busy_block(multistatus, block)
    available = properties.event(etag: block.etag, ics: Caldav::BusyBlockIcs.render(block))
    requested = request_body.props.presence || [Caldav::Properties::GETETAG, Caldav::Properties::CALENDAR_DATA]
    selection = Caldav::Properties.select(available, requested:, allprop: false)
    multistatus.add(properties.event_href(block.href_name), **selection)
  end

  def add_resource(multistatus, href, available)
    selection = Caldav::Properties.select(available, requested: request_body.props, allprop: request_body.allprop?)
    multistatus.add(href, **selection)
  end

  def render_multistatus(multistatus)
    render xml: multistatus.to_xml, status: :multi_status, content_type: "application/xml; charset=utf-8"
  end

  def calendar_ics
    Caldav::BusyBlockIcs.render(*connection.busy_blocks.live.order(:starts_at))
  end

  def refresh_provider_data
    Providers.refresh_if_stale(connection.account)
  end
end
