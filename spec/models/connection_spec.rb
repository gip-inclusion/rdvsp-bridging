require "rails_helper"

RSpec.describe Connection do
  let(:password) { described_class.generate_password }
  let(:connection) { create(:connection, password:) }

  describe ".authenticate" do
    it "finds the active connection matching the credentials" do
      expect(described_class.authenticate(connection.username, password)).to eq(connection)
    end

    it "refuses a wrong password, an unknown username and a disabled connection" do
      expect(described_class.authenticate(connection.username, "wrong")).to be_nil
      expect(described_class.authenticate("unknown", password)).to be_nil
      connection.update!(disabled_at: Time.current)
      expect(described_class.authenticate(connection.username, password)).to be_nil
    end

    it "upgrades a bcrypt digest from earlier versions on the next successful authentication" do
      connection.update_column(:password_digest, BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST))

      expect(described_class.authenticate(connection.username, "wrong")).to be_nil
      expect(described_class.authenticate(connection.username, password)).to eq(connection)
      expect(connection.reload.password_digest).to eq(OpenSSL::Digest::SHA256.hexdigest(password))
    end
  end

  it "stores a SHA-256 digest of the password, never the password" do
    expect(connection.reload.password_digest).to eq(OpenSSL::Digest::SHA256.hexdigest(password))
    expect(connection.attributes.values).not_to include(password)
  end
end
