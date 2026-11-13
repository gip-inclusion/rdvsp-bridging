module UsagerImports
  # Creates persons as usagers of an RDV-SP organisation, and records which person became which usager
  class Transfer
    CONTACT = %i[email phone_number].freeze

    Created = Data.define(:imported_usager, :without_contact)

    # RDV-SP refuses a second usager with the same reference: this one was created already
    def self.taken?(error)
      error.codes.any? { |attribute, codes| attribute.end_with?("external_id") && codes.include?("taken") }
    end

    def initialize(account:, organisation_id:, usager_import: nil)
      @account = account
      @organisation_id = organisation_id
      @usager_import = usager_import
    end

    # RDV-SP rejects some e-mails and phones (a typo, a foreign number): the usager is then created without both.
    # Raises Rdvsp::UnprocessableError when RDV-SP refuses the usager.
    def create(person)
      Created.new(record(person, client.create_user(attributes_for(person)).fetch("id")), false)
    rescue Rdvsp::UnprocessableError => e
      raise if self.class.taken?(e) || !contact?(person) || (e.codes.keys - CONTACT.map(&:to_s)).any?

      Created.new(record(person, client.create_user(attributes_for(person).except(*CONTACT)).fetch("id")), true)
    end

    def record(person, usager_id)
      ImportedUsager.create!(account: @account, usager_import: @usager_import, provider_person_id: person.id,
                             rdvsp_user_id: usager_id, rdvsp_organisation_id: @organisation_id)
    end

    private

    # Pipedrive numbers persons per company, and all partners share the bridge's OAuth application at RDV-SP
    def attributes_for(person)
      {
        first_name: person.first_name, last_name: person.last_name, email: person.email, phone_number: person.phone,
        organisation_ids: [@organisation_id],
        external_reference: { external_id: "#{@account.provider}-#{@account.provider_company_id}-#{person.id}",
                              external_url: @account.provider_person_url(person.id), }.compact,
      }.compact
    end

    def contact?(person) = person.email.present? || person.phone.present?

    def client = @client ||= Rdvsp::Client.new(@account.rdvsp_authorization)
  end
end
