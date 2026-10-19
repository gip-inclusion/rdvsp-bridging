FactoryBot.define do
  factory :account do
    provider { "pipedrive" }
    sequence(:name) { |n| "Entreprise #{n}" }
    sequence(:provider_company_id, &:to_s)
    api_token { "pipedrive-token" }
    rdv_activity_type_key { "rdv_service_public" }
  end
end
