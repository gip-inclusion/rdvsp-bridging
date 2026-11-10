require "rails_helper"

RSpec.describe Rdvs::Ignore do
  let(:connection) { create(:connection) }

  it "ignores the RDVs, schedules the removal of the activities they have and raises the watermark" do
    pushed = create(:rdv, connection:, provider_object_id: "77", state: "synced", payload: nil, rdvsp_id: 10)
    never_pushed = create(:rdv, connection:, state: "failed", rdvsp_id: 20)

    expect(described_class.call(rdvs: connection.rdvs).count).to eq(2)

    expect(pushed.reload).to have_attributes(ignored?: true, state: "pending")
    expect(never_pushed.reload).to have_attributes(ignored?: true, state: "synced", payload: nil)
    expect(PushRdvJob).to have_been_enqueued.with(pushed).exactly(:once)
    expect(PushRdvJob).not_to have_been_enqueued.with(never_pushed)
    expect(connection.below_baseline_watermark?(20)).to be(true)
  end

  it "leaves the RDVs already ignored alone" do
    create(:rdv, connection:, ignored_at: 1.day.ago, payload: nil)

    expect(described_class.call(rdvs: connection.rdvs).count).to eq(0)
  end
end
