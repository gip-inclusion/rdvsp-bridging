module PipedriveHelpers
  API = "https://api.pipedrive.com".freeze

  def pipedrive_activity(id:, owner_id:, due_date: Date.tomorrow.iso8601, due_time: "08:00", duration: "01:00", **attrs)
    { "id" => id, "owner_id" => Integer(owner_id), "type" => "meeting", "busy" => true, "done" => false,
      "is_deleted" => false, "due_date" => due_date, "due_time" => due_time, "duration" => duration, }
      .merge(attrs.transform_keys(&:to_s))
  end

  # A v1 person, a beneficiary active in 2025 by default (field "abc123", option "34")
  def pipedrive_person(id, **attrs)
    { "id" => id, "first_name" => "Ada", "last_name" => "Lovelace", "add_time" => "2020-05-01 10:00:00",
      "last_activity_date" => "2025-06-01", "next_activity_date" => nil, "abc123" => "12,34",
      "email" => [{ "value" => "", "primary" => false }], "phone" => [], }.merge(attrs.transform_keys(&:to_s))
  end

  def stub_pipedrive_persons(*pages)
    pages.each_with_index do |persons, index|
      pagination = { more_items_in_collection: index < pages.size - 1, next_start: (index + 1) * 500 }
      stub_request(:get, "#{API}/v1/persons").with(query: { start: (index * 500).to_s, limit: "500" })
        .to_return_json(body: { success: true, data: persons, additional_data: { pagination: } })
    end
  end

  def stub_pipedrive_activities(activities, query: hash_including({}))
    stub_request(:get, "#{API}/api/v2/activities").with(query:)
      .to_return_json(body: { success: true, data: activities, additional_data: { next_cursor: nil } })
  end
end

RSpec.configure { it.include PipedriveHelpers }
