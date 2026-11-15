require "rails_helper"

RSpec.describe AdminHelper do
  it "counts in French: singular up to one" do
    expect([0, 1, 3].map { helper.count_label(it, "ignoré") }).to eq(["0 ignoré", "1 ignoré", "3 ignorés"])
    expect(helper.count_label(2, "transmis", "transmis")).to eq("2 transmis")
  end

  it "tells whether RDV-SP comes to a connection" do
    never = build(:connection, last_seen_at: nil)
    silent = build(:connection, last_seen_at: 2.hours.ago, silence_alerted_at: 1.hour.ago)
    back = build(:connection, last_seen_at: 5.minutes.ago, silence_alerted_at: 1.hour.ago)

    expect(helper.connection_badge(never)).to include("RDV-SP jamais venu", "text-warning")
    expect(helper.connection_badge(silent)).to include("RDV-SP ne passe plus", "text-danger")
    expect(helper.connection_badge(back)).to include("Synchronisée", "text-success")
  end

  it "colors an RDV by its state" do
    expect(helper.rdv_badge(build(:rdv, ignored_at: Time.current))).to include("Ignoré", "text-info")
    expect(helper.rdv_badge(build(:rdv, state: "failed"))).to include("En échec", "text-danger")
    transmitted = build(:rdv, state: "synced", provider_object_id: "1")
    expect(helper.rdv_badge(transmitted)).to include("Transmis", "text-success")
  end

  it "gives an account's domain and failure" do
    account = build(:account, provider_company_domain: "acme", failing_since: Time.zone.local(2026, 11, 12, 9, 40))

    expect(helper.account_source(account)).to eq("Pipedrive · acme.pipedrive.com")
    expect(helper.account_badge(account)).to include("En erreur depuis le", "text-danger")
  end
end
