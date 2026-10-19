FactoryBot.define do
  factory :connection do
    account
    sequence(:provider_user_id) { |n| (1000 + n).to_s }
    provider_user_name { "Camille Martin" }
    agent_email { "camille.martin@example.fr" }
    password { "caldav-password" }
  end
end
