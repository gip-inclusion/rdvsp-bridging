class BusyBlockChange < ApplicationRecord
  belongs_to :connection

  def self.next_seq(connection) = create!(connection:).id
end
