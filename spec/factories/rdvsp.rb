FactoryBot.define do
  factory :rdvsp_authorization do
    account
    sequence(:agent_id) { |n| 1000 + n }
    agent_email { "agent@example.fr" }
    access_token { "rdvsp-access" }
    refresh_token { "rdvsp-refresh" }
    expires_at { 2.hours.from_now }
  end

  factory :usager_import do
    account
    rdvsp_organisation_id { 42 }
    field_key { "type_de_contact" }
    option_id { "7" }
    active_since { Date.new(2025, 1, 1) }
  end

  factory :imported_usager do
    account
    sequence(:provider_person_id, &:to_s)
    sequence(:rdvsp_user_id) { |n| 5000 + n }
    rdvsp_organisation_id { 42 }
  end
end
