require "rails_helper"

RSpec.describe Rdvs::Cancel do
  let(:connection) { create(:connection) }

  it "cancels the RDV and schedules the removal of its activity" do
    rdv = create(:rdv, connection:)

    described_class.call(connection:, href_name: rdv.href_name)

    expect(rdv.reload).to have_attributes(cancelled?: true, state: "pending")
    expect(PushRdvJob).to have_been_enqueued.with(rdv)
  end

  it "pushes nothing for an ignored RDV" do
    rdv = create(:rdv, connection:, ignored_at: Time.current, payload: nil)

    described_class.call(connection:, href_name: rdv.href_name)

    expect(rdv.reload).to have_attributes(cancelled?: true, state: "synced")
    expect(PushRdvJob).not_to have_been_enqueued
  end
end
