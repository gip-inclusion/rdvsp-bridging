require "rails_helper"

RSpec.describe ImportUsagersJob, :rdvsp do
  let(:usager_import) { create(:usager_import) }

  it "marks the import as failed when the authorization is lost" do
    create(:rdvsp_authorization, account: usager_import.account, lost_at: 1.day.ago, expires_at: 1.hour.ago)

    described_class.perform_now(usager_import)

    expect(usager_import.reload).to have_attributes(state: "failed", error: /authorize the bridge again/,
                                                    finished_at: be_present)
  end
end
