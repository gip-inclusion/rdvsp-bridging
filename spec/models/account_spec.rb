require "rails_helper"

RSpec.describe Account do
  describe "#provider_person_url" do
    it "links to the person's page in Pipedrive" do
      expect(build(:account, provider_company_domain: "acme").provider_person_url("7"))
        .to eq("https://acme.pipedrive.com/person/7")
    end

    it "is unknown without the company's domain, or for another provider" do
      expect(build(:account, provider_company_domain: nil).provider_person_url("7")).to be_nil
      expect(build(:account, provider: "google", provider_company_domain: "acme").provider_person_url("7")).to be_nil
    end
  end
end
