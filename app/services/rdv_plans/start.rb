module RdvPlans
  # Opens an RDV-SP RDV plan for a Pipedrive person, where the agent picks the motif and the slot. A person not
  # transferred yet is transferred first, with the import's rules, into the account's organisation.
  # Failures set result.reason.
  class Start < BaseService
    def initialize(account:, person_id:, return_url:)
      @account = account
      @person_id = person_id.to_s
      @return_url = return_url
    end

    def call
      authorization = @account.rdvsp_authorization
      stop(:no_authorization) if authorization.nil? || authorization.lost?

      # By id, never by external_id: RDV-SP's lookup by it was broken (betagouv/rdv-service-public#6937)
      plan = client.create_rdv_plan(user: { id: usager_id }, return_url: @return_url,
                                    dossier_url: @account.provider_person_url(@person_id))
      result.url = plan.fetch("url")
    rescue Rdvsp::AuthenticationError
      stop(:no_authorization)
    end

    private

    def usager_id = @account.imported_usagers.find_by(provider_person_id: @person_id)&.rdvsp_user_id || transfer

    # A usager with the person's e-mail or phone is theirs; one with only their name may be someone else, whom RDV-SP
    # would notify of the RDV: the agent then books in RDV-SP
    def transfer
      organisation_id = rdvsp_organisation_id
      person = pipedrive_person
      stop(:incomplete_name) if person.first_name.blank? || person.last_name.blank?

      index = UsagerImports::UsagerIndex.new
      client.each_organisation_user(organisation_id) { index.add_usager(it) }
      transfer = UsagerImports::Transfer.new(account: @account, organisation_id:)
      existing_id = index.usager_id(person)
      return transfer.record(person, existing_id).rdvsp_user_id if existing_id

      stop(:homonym) if index.include?(person)
      transfer.create(person).imported_usager.rdvsp_user_id
    rescue Rdvsp::UnprocessableError => e
      Rails.logger.info("RDV-SP refused person #{@person_id} of account #{@account.id}: #{e.message}")
      stop(:rejected)
    end

    # Chosen in the admin or by the last import; otherwise the agent's only one, kept for the next clicks
    def rdvsp_organisation_id
      return @account.rdvsp_organisation_id if @account.rdvsp_organisation_id

      organisations = client.organisations
      stop(:no_organisation) unless organisations.one?
      @account.update!(rdvsp_organisation_id: organisations.sole.fetch("id"))
      @account.rdvsp_organisation_id
    end

    def pipedrive_person
      Pipedrive::Beneficiaries::Person.from_pipedrive(Pipedrive::Client.new(@account.api_token).person(@person_id))
    rescue Pipedrive::NotFoundError
      stop(:unknown_person)
    end

    def stop(reason)
      result.reason = reason
      fail!(reason.to_s)
    end

    def client = @client ||= Rdvsp::Client.new(@account.rdvsp_authorization)
  end
end
