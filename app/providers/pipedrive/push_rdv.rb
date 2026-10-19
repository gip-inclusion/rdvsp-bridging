module Pipedrive
  # Creates, updates or deletes the Pipedrive activity mirroring an RDV received from RDV-SP
  class PushRdv < BaseService
    def initialize(rdv:)
      @rdv = rdv
    end

    def call
      @rdv.cancelled? ? delete_activity : upsert_activity
      @rdv.update!(state: "synced", pushed_at: Time.current, last_error: nil, payload: nil)
    rescue Pipedrive::Error => e
      @rdv.update!(state: "failed", last_error: e.message.truncate(1_000))
      raise
    end

    private

    def account = @rdv.connection.account

    def client = @client ||= Client.new(account.api_token)

    def delete_activity
      return if @rdv.provider_object_id.nil?

      client.delete_activity(@rdv.provider_object_id)
    rescue Pipedrive::NotFoundError
      nil
    end

    def upsert_activity
      attributes = RdvActivity.new(@rdv, person_id:).attributes
      activity = update_existing(attributes) || client.create_activity(attributes)
      @rdv.update!(provider_object_id: activity["id"].to_s)
    end

    # The partner may have deleted the activity in Pipedrive: RDV-SP stays the source of truth, so we recreate it
    def update_existing(attributes)
      return if @rdv.provider_object_id.nil?

      activity = client.update_activity(@rdv.provider_object_id, attributes)
      activity unless activity["is_deleted"]
    rescue Pipedrive::NotFoundError
      nil
    end

    def person_id
      return @rdv.provider_person_id if @rdv.provider_person_id.present?
      return unless account.link_persons && account.usager_details

      person = FindOrCreatePerson.new(client, @rdv.payload).call
      @rdv.update!(provider_person_id: person["id"].to_s) if person
      @rdv.provider_person_id
    end
  end
end
