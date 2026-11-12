module Pipedrive
  # The persons a partner marks as beneficiaries with one option of a set or single-option field, and active since a
  # date: an activity since then, an upcoming one, or created since then. update_time can't tell: a bulk edit bumped it
  # on every person of the first partner.
  class Beneficiaries
    include Enumerable

    Person = Data.define(:id, :first_name, :last_name, :email, :phone)

    # [["Field → Option", "field_key:option_id"], …] for the fields that can mark a beneficiary
    def self.options(client)
      client.person_fields.select { it["field_type"].in?(%w[set enum]) }.flat_map do |field|
        Array(field["options"]).map { ["#{field['name']} → #{it['label']}", "#{field['key']}:#{it['id']}"] }
      end
    end

    def initialize(client, field_key:, option_id:, active_since:)
      @client = client
      @field_key = field_key
      @option_id = option_id.to_s
      @active_since = active_since.iso8601
    end

    def each
      @client.each_person do |person|
        yield to_person(person) if marked?(person) && active?(person)
      end
    end

    private

    def marked?(person) = person[@field_key].to_s.split(",").map(&:strip).include?(@option_id)

    def active?(person)
      person["next_activity_date"].present? ||
        [person["last_activity_date"], person["add_time"]].compact.any? { it.to_s.first(10) >= @active_since }
    end

    def to_person(person)
      Person.new(id: person["id"].to_s, first_name: person["first_name"].to_s.squish.presence,
                 last_name: person["last_name"].to_s.squish.presence,
                 email: primary(person["email"]), phone: primary(person["phone"]))
    end

    def primary(values)
      values = Array(values).select { it["value"].to_s.strip.present? }
      (values.find { it["primary"] } || values.first)&.dig("value")&.strip
    end
  end
end
