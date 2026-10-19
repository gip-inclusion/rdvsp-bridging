module PipedriveHelpers
  API = "https://api.pipedrive.com".freeze

  def pipedrive_activity(id:, owner_id:, due_date: Date.tomorrow.iso8601, due_time: "08:00", duration: "01:00", **attrs)
    { "id" => id, "owner_id" => Integer(owner_id), "type" => "meeting", "busy" => true, "done" => false,
      "is_deleted" => false, "due_date" => due_date, "due_time" => due_time, "duration" => duration, }
      .merge(attrs.transform_keys(&:to_s))
  end

  def stub_pipedrive_activities(activities, query: hash_including({}))
    stub_request(:get, "#{API}/api/v2/activities").with(query:)
      .to_return_json(body: { success: true, data: activities, additional_data: { next_cursor: nil } })
  end
end

RSpec.configure { it.include PipedriveHelpers }
