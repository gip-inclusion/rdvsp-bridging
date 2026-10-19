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
end
