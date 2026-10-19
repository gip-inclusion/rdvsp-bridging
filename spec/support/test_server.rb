require "puma"

# Serves the app over real HTTP, for clients that can't use Rack::Test (the Calendav gem)
module TestServer
  def self.url
    @url ||= begin
      methods = Puma::Const::SUPPORTED_HTTP_METHODS + %w[PROPFIND PROPPATCH REPORT MKCALENDAR]
      server = Puma::Server.new(Rails.application, nil, min_threads: 0, max_threads: 4,
                                                        log_writer: Puma::LogWriter.null,
                                                        supported_http_methods: methods)
      server.add_tcp_listener("127.0.0.1", 0)
      server.run
      "http://127.0.0.1:#{server.connected_ports.first}"
    end
  end
end
