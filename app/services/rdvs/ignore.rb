# Ignores RDVs after the fact (see Rdv#ignored?), for RDVs that existed before the connection but were pushed
# anyway: they keep no content, the activities they already have are removed, and the watermark learns their ids
module Rdvs
  class Ignore < BaseService
    def initialize(rdvs:)
      @rdvs = rdvs
    end

    def call
      result.count = 0
      @rdvs.where(ignored_at: nil).find_each do |rdv|
        rdv.assign_attributes(ignored_at: Time.current, payload: nil)
        rdv.update!(state: rdv.needs_push? ? "pending" : "synced")
        rdv.connection.raise_baseline_watermark!(rdv.rdvsp_id)
        PushRdvJob.perform_later(rdv) if rdv.needs_push?
        result.count += 1
      end
    end
  end
end
