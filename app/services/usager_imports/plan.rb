module UsagerImports
  # Sorts a partner's beneficiaries before creating them as usagers of an RDV-SP organisation. Counts only, no names.
  class Plan < BaseService
    CATEGORIES = %w[already_imported incomplete_name already_in_rdvsp to_create].freeze

    def initialize(account:, organisation_id:, field_key:, option_id:, active_since:)
      @account = account
      @organisation_id = organisation_id
      pipedrive = Pipedrive::Client.new(account.api_token)
      @beneficiaries = Pipedrive::Beneficiaries.new(pipedrive, field_key:, option_id:, active_since:)
    end

    def call
      imported = @account.imported_usagers.pluck(:provider_person_id).to_set
      index = UsagerIndex.new
      Rdvsp::Client.new(@account.rdvsp_authorization).each_organisation_user(@organisation_id) { index.add_usager(it) }

      result.counts = { "selected" => 0, **CATEGORIES.index_with(0) }
      result.to_create = []
      @beneficiaries.each do |person|
        result.counts["selected"] += 1
        result.counts[category(person, imported, index)] += 1
      end
    end

    private

    # A person to create joins the index, so that a second Pipedrive person with the same e-mail isn't created too
    def category(person, imported, index)
      return "already_imported" if imported.include?(person.id)
      return "incomplete_name" if person.first_name.blank? || person.last_name.blank?
      return "already_in_rdvsp" if index.include?(person)

      index.add_person(person)
      result.to_create << person
      "to_create"
    end
  end
end
