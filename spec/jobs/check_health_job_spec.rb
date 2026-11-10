require "rails_helper"

RSpec.describe CheckHealthJob do
  let(:paris) { Time.find_zone("Europe/Paris") }

  it "alerts us and the partner once an account has been failing for over an hour, then daily" do
    account = create(:account, failing_since: 2.hours.ago, last_error: "token revoked", alert_email: "admin@partner.fr")
    create(:connection, account:)

    expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :account_failing).with(account)
    expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :account_failing)
  end

  it "waits for the grace period" do
    create(:connection, account: create(:account, failing_since: 10.minutes.ago))

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "leaves alone an account whose connections are all disabled" do
    account = create(:account, failing_since: 2.days.ago, last_error: "token revoked")
    create(:connection, account:, disabled_at: 1.day.ago)

    expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :account_failing)
  end

  describe "when RDV-SP stops coming" do
    before { allow(Rails.error).to receive(:report) }

    it "alerts us once it missed two of its 10-minute imports in the daytime" do
      travel_to paris.local(2026, 11, 12, 14, 35)
      silent = create(:connection, last_seen_at: paris.local(2026, 11, 12, 14, 1))
      create(:connection, last_seen_at: paris.local(2026, 11, 12, 14, 11))
      create(:connection, last_seen_at: nil)
      create(:connection, last_seen_at: 2.hours.ago, disabled_at: 1.day.ago)

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([silent])
      expect(Rails.error).to have_received(:report).with(instance_of(CheckHealthJob::ConnectionsSilent), anything)
      expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :connections_silent)
    end

    it "stays quiet at night, when RDV-SP imports nothing, then alerts if it misses the first two morning imports" do
      connection = create(:connection, last_seen_at: paris.local(2026, 11, 12, 23, 31))

      travel_to paris.local(2026, 11, 13, 3, 0)
      expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :connections_silent)
      travel_to paris.local(2026, 11, 13, 5, 45)
      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end

    it "allows for the half-hourly imports of the evening" do
      connection = create(:connection, last_seen_at: paris.local(2026, 11, 12, 20, 31))

      travel_to paris.local(2026, 11, 12, 21, 15)
      expect { described_class.perform_now }.not_to have_enqueued_mail(AlertMailer, :connections_silent)
      travel_to paris.local(2026, 11, 12, 21, 45)
      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end

    it "repeats the alert daily while the silence lasts" do
      travel_to paris.local(2026, 11, 12, 14, 35)
      connection = create(:connection, last_seen_at: paris.local(2026, 11, 12, 14, 1))
      described_class.perform_now
      travel 1.day + 1.minute

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end

    it "alerts again when RDV-SP came back in between" do
      travel_to paris.local(2026, 11, 12, 14, 35)
      connection = create(:connection, last_seen_at: paris.local(2026, 11, 12, 14, 1))
      described_class.perform_now
      connection.update!(last_seen_at: paris.local(2026, 11, 12, 14, 40))
      travel_to paris.local(2026, 11, 12, 15, 15)

      expect { described_class.perform_now }.to have_enqueued_mail(AlertMailer, :connections_silent).with([connection])
    end
  end
end
