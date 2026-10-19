# RDV-SP removed an RDV from a connection's calendar
module Rdvs
  class Cancel < BaseService
    def initialize(connection:, href_name:)
      @connection = connection
      @href_name = href_name
    end

    def call
      rdv = @connection.rdvs.find_by(href_name: @href_name)
      fail!("not found") if rdv.nil? || rdv.cancelled?

      rdv.update!(cancelled_at: Time.current, state: "pending", payload: nil)
      PushRdvJob.perform_later(rdv)
      result.rdv = rdv
    end
  end
end
