FactoryBot.define do
  factory :rdv do
    connection
    sequence(:href_name) { |n| "#{SecureRandom.uuid}-#{n}.ics" }
    uid { href_name.delete_suffix(".ics") }
    starts_at { 2.days.from_now.change(hour: 9) }
    ends_at { starts_at + 30.minutes }
    etag { %("#{SecureRandom.hex(4)}") }
    payload { { "summary" => "RDV Accueil", "description" => "", "location" => "" } }
  end
end
