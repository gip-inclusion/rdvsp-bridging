module UsagerImports
  # Creates a partner's beneficiaries as usagers of an RDV-SP organisation, and records which person became which
  # usager. Running it again creates only the new ones.
  class Run < BaseService
    CONTACT = %i[email phone_number].freeze
    PROGRESS_EVERY = 25

    def initialize(usager_import:)
      @import = usager_import
      @account = usager_import.account
    end

    def call
      @import.update!(state: "running", started_at: Time.current, finished_at: nil, error: nil)
      plan = Plan.call(account: @account, organisation_id: @import.rdvsp_organisation_id, field_key: @import.field_key,
                       option_id: @import.option_id, active_since: @import.active_since)
      @counts = plan.counts.merge("created" => 0, "created_without_contact" => 0, "rejected" => 0)
      @rejections = Hash.new(0)

      plan.to_create.each_with_index do |person, index|
        create(person)
        save_progress if ((index + 1) % PROGRESS_EVERY).zero?
      end
      @import.update!(state: "done", finished_at: Time.current, counts: @counts, rejections: @rejections)
    end

    private

    # RDV-SP rejects some e-mails and phones (a typo, a foreign number): the usager is then created without both
    def create(person, without_contact: false)
      attributes = attributes_for(person)
      user = client.create_user(without_contact ? attributes.except(*CONTACT) : attributes)
      ImportedUsager.create!(account: @account, usager_import: @import, provider_person_id: person.id,
                             rdvsp_user_id: user.fetch("id"), rdvsp_organisation_id: @import.rdvsp_organisation_id)
      @counts[without_contact ? "created_without_contact" : "created"] += 1
    rescue Rdvsp::UnprocessableError => e
      if e.codes.any? { |attribute, codes| attribute.end_with?("external_id") && codes.include?("taken") }
        @counts["already_imported"] += 1
      elsif !without_contact && contact?(person) && (e.codes.keys - CONTACT.map(&:to_s)).empty?
        create(person, without_contact: true)
      else
        @counts["rejected"] += 1
        @rejections[e.codes.keys.sort.join(", ")] += 1
      end
    end

    def attributes_for(person)
      {
        first_name: person.first_name, last_name: person.last_name, email: person.email, phone_number: person.phone,
        organisation_ids: [@import.rdvsp_organisation_id],
        external_reference: { external_id: external_id(person), external_url: person_url(person) }.compact,
      }.compact
    end

    # Persons are numbered per Pipedrive company, and all partners share the bridge's OAuth application at RDV-SP
    def external_id(person) = "#{@account.provider}-#{@account.provider_company_id}-#{person.id}"

    def contact?(person) = person.email.present? || person.phone.present?

    def person_url(person)
      domain = @account.provider_company_domain
      "https://#{domain}.pipedrive.com/person/#{person.id}" if domain
    end

    def save_progress = @import.update!(counts: @counts, rejections: @rejections)

    def client = @client ||= Rdvsp::Client.new(@account.rdvsp_authorization)
  end
end
