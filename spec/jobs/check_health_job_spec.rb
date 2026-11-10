require "rails_helper"

RSpec.describe CheckHealthJob do
  it "alerts us and the partner once an account has been failing for over an hour, then daily" do
    account = create(:account, failing_since: 2.hours.ago, last_error: "token revoked", alert_email: "admin@partner.fr")

    expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :account_failing).with(account)
    expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :account_failing)
  end

  it "waits for the grace period" do
    create(:account, failing_since: 10.minutes.ago)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  describe "when RDV-SP stops coming" do
    before { allow(Rails.error).to receive(:report) }

    it "alerts us once about the active connections it hasn't polled for half an hour" do
      silent = create(:connection, last_seen_at: 40.minutes.ago)
      create(:connection, last_seen_at: 5.minutes.ago)
      create(:connection, last_seen_at: nil)
      create(:connection, last_seen_at: 2.hours.ago, disabled_at: 1.day.ago)

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([silent])
      expect(Rails.error).to have_received(:report).with(instance_of(CheckHealthJob::ConnectionsSilent), anything)
      expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :connections_silent)
    end

    it "repeats the alert daily while the silence lasts" do
      connection = create(:connection, last_seen_at: 40.minutes.ago)
      described_class.perform_now
      travel 1.day + 1.minute

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end

    it "alerts again when RDV-SP came back in between" do
      connection = create(:connection, last_seen_at: 40.minutes.ago)
      described_class.perform_now
      connection.update!(last_seen_at: Time.current)
      travel 40.minutes

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end
  end
end
