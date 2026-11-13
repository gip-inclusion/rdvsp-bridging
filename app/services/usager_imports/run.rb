module UsagerImports
  # Creates a partner's beneficiaries as usagers of an RDV-SP organisation, and records which person became which
  # usager. Running it again creates only the new ones.
  class Run < BaseService
    PROGRESS_EVERY = 25

    def initialize(usager_import:)
      @import = usager_import
      @account = usager_import.account
      @transfer = Transfer.new(account: @account, organisation_id: @import.rdvsp_organisation_id, usager_import:)
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

    def create(person)
      created = @transfer.create(person)
      @counts[created.without_contact ? "created_without_contact" : "created"] += 1
    rescue Rdvsp::UnprocessableError => e
      if Transfer.taken?(e)
        @counts["already_imported"] += 1
      else
        @counts["rejected"] += 1
        @rejections[e.codes.keys.sort.join(", ")] += 1
      end
    end

    def save_progress = @import.update!(counts: @counts, rejections: @rejections)
  end
end
