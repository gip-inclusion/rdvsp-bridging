FactoryBot.define do
  factory :busy_block do
    connection
    sequence(:provider_object_id, &:to_s)
    starts_at { 1.day.from_now.change(hour: 8) }
    ends_at { starts_at + 1.hour }
    seq { BusyBlockChange.next_seq(connection) }
  end
end
