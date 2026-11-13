module Pipedrive
  # Creates, updates or deletes the Pipedrive activity mirroring an RDV received from RDV-SP
  class PushRdv < BaseService
    def initialize(rdv:)
      @rdv = rdv
    end

    def call
      if @rdv.ignored? then remove_activity
      elsif @rdv.cancelled? then delete_activity
      else upsert_activity
      end
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
    rescue Pipedrive::Error
      raise unless activity_deleted?
    end

    # The RDV existed before the connection: the partner has their own copy, ours must go
    def remove_activity
      delete_activity
      @rdv.update!(provider_object_id: nil)
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
    rescue Pipedrive::Error
      raise unless activity_deleted?
    end

    # Pipedrive refuses to update (403) or delete (400) a deleted activity instead of answering 404
    def activity_deleted?
      client.activity(@rdv.provider_object_id)["is_deleted"]
    rescue Pipedrive::NotFoundError
      true
    end

    # The person of the usager the bridge transferred, otherwise one with their name (which only the details carry)
    def person_id
      return @rdv.provider_person_id if @rdv.provider_person_id.present?
      return unless account.link_persons

      person_id = UsagerImports::RdvPerson.new(account).person_id(@rdv.rdvsp_id) || person_id_by_name
      @rdv.update!(provider_person_id: person_id) if person_id
      @rdv.provider_person_id
    end

    def person_id_by_name
      FindOrCreatePerson.new(client, @rdv.payload).call&.fetch("id")&.to_s if account.usager_details
    end
  end
end
