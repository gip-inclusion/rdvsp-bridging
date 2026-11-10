require "rails_helper"

RSpec.describe AlertMailer do
  it "lists the connections RDV-SP stopped polling, with when it last came (Paris time)" do
    connection = create(:connection, agent_email: "agent@example.fr", last_seen_at: Time.utc(2026, 11, 10, 15, 52))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ALERT_EMAIL").and_return("us@example.fr")

    mail = described_class.connections_silent([connection])

    expect(mail.to).to eq(["us@example.fr"])
    expect(mail.subject).to include("1 agenda")
    expect(mail.body.encoded).to include("agent@example.fr", "16h52")
  end
end
