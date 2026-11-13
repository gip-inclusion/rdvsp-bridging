module UsagerImports
  # The Pipedrive person of an RDV-SP RDV: that of its only participant the bridge transferred. Asks RDV-SP as the agent
  # who authorized the bridge, so nil when they can't see the RDV, or when RDV-SP fails.
  class RdvPerson
    def initialize(account)
      @account = account
    end

    def person_id(rdvsp_id)
      authorization = @account.rdvsp_authorization
      return if rdvsp_id.nil? || authorization.nil? || authorization.lost?

      user_ids = Rdvsp::Client.new(authorization).rdv_user_ids(rdvsp_id)
      return if user_ids.blank?

      person_ids = @account.imported_usagers.where(rdvsp_user_id: user_ids).distinct.pluck(:provider_person_id)
      person_ids.first if person_ids.one?
    rescue Rdvsp::Error => e
      Rails.logger.warn("RDV-SP participants of RDV #{rdvsp_id} unavailable for account #{@account.id}: #{e.message}")
      nil
    end
  end
end
