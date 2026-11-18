require "rails_helper"

RSpec.describe PartnerLink do
  let(:link) { create(:partner_link) }

  it "is found by its token while it isn't revoked" do
    token = link.generate_token_for(:partner_access)

    expect(described_class.from_token(token)).to eq(link)
    expect(described_class.from_token("nope")).to be_nil

    link.revoke!
    expect(described_class.from_token(token)).to be_nil
  end

  it "counts its uses" do
    freeze_time

    2.times { link.record_use! }

    expect(link.reload).to have_attributes(uses_count: 2, last_used_at: Time.current)
  end

  it "needs a label" do
    expect(build(:partner_link, label: " ")).not_to be_valid
  end
end
