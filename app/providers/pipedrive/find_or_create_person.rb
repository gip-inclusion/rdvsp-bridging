module Pipedrive
  # Best effort: RDV-SP only shares the usager's name (in the summary, "Prénom Nom - Motif") and, for phone RDVs,
  # their phone number (as the location). Links to an existing person only when exactly one matches the name.
  class FindOrCreatePerson
    PHONE = /\A\+?[\d .()-]{8,}\z/

    def initialize(client, payload)
      @client = client
      @payload = payload || {}
    end

    def call
      return if name.blank?

      matches = @client.search_persons(name)
      return matches.first["item"] if matches.size == 1

      @client.create_person({ name:, phones: phone ? [{ value: phone, primary: true, label: "work" }] : nil }.compact)
    end

    private

    def name
      summary = @payload["summary"].to_s
      summary.start_with?("RDV ") || summary.exclude?(" - ") ? nil : summary.split(" - ").first.strip
    end

    def phone
      location = @payload["location"].to_s.strip
      location if location.match?(PHONE)
    end
  end
end
