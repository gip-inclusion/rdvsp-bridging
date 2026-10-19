require "rails_helper"

RSpec.describe Pipedrive::BusyMapping do
  subject(:times) { described_class.new(connection).times_for(activity) }

  let(:connection) { create(:connection, provider_user_id: "7") }
  let(:tomorrow) { Date.tomorrow }
  let(:activity) do
    pipedrive_activity(id: 1, owner_id: 7, due_date: tomorrow.iso8601, due_time: "08:00", duration: "00:45")
  end

  it "reads due_date and due_time as UTC" do
    expect(times).to eq(starts_at: Time.utc(tomorrow.year, tomorrow.month, tomorrow.day, 8),
                        ends_at: Time.utc(tomorrow.year, tomorrow.month, tomorrow.day, 8, 45))
  end

  it "defaults to 30 minutes without a duration" do
    activity["duration"] = nil

    expect(times[:ends_at] - times[:starts_at]).to eq(30.minutes)
  end

  it "keeps done activities and activities without a busy flag" do
    activity.merge!("done" => true, "busy" => nil)

    expect(times).to be_present
  end

  it "ignores free, deleted, other users' and out-of-window activities" do
    [{ "busy" => false }, { "is_deleted" => true }, { "owner_id" => 8 },
     { "due_date" => 1.year.from_now.to_date.iso8601 }, { "due_date" => 1.month.ago.to_date.iso8601 },].each do |change|
      expect(described_class.new(connection).times_for(activity.merge(change))).to be_nil
    end
  end

  it "ignores the activities the bridge created for RDVs" do
    expect(described_class.new(connection).times_for(activity.merge("type" => "rdv_service_public"))).to be_nil

    create(:rdv, connection:, provider_object_id: "1")
    expect(described_class.new(connection).times_for(activity)).to be_nil
  end

  describe "all-day activities" do
    before { activity["due_time"] = nil }

    it "ignores them by default" do
      expect(times).to be_nil
    end

    it "blocks the whole day in Paris when the connection asks for it" do
      connection.update!(include_all_day: true)
      paris = Time.find_zone("Europe/Paris")

      expect(times).to eq(starts_at: paris.local(tomorrow.year, tomorrow.month, tomorrow.day),
                          ends_at: paris.local(tomorrow.year, tomorrow.month, tomorrow.day) + 1.day)
    end
  end
end
