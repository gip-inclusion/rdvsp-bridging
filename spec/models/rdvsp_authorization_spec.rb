require "rails_helper"

RSpec.describe RdvspAuthorization do
  let(:account) { create(:account) }

  it "encrypts the tokens and allows one authorization per account" do
    authorization = create(:rdvsp_authorization, account:, access_token: "access-1", refresh_token: "refresh-1")

    raw = described_class.connection.select_one("SELECT access_token, refresh_token FROM rdvsp_authorizations")
    expect(raw.values).not_to include("access-1", "refresh-1")
    expect(authorization.reload.access_token).to eq("access-1")
    expect(build(:rdvsp_authorization, account:)).not_to be_valid
  end

  it "goes away with its account, as do the account's imports" do
    create(:rdvsp_authorization, account:)
    usager_import = create(:usager_import, account:)
    create(:imported_usager, account:, usager_import:)

    expect { account.destroy! }.to change(described_class, :count).by(-1)
      .and change(UsagerImport, :count).by(-1).and change(ImportedUsager, :count).by(-1)
  end
end
