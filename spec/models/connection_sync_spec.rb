require "rails_helper"

RSpec.describe Connection do
  let(:connection) { create(:connection) }
  let(:starts_at) { 1.day.from_now.change(min: 0) }

  describe "#changes_since" do
    it "returns only what changed since the token, tombstones included" do
      connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)
      connection.upsert_busy_block!("2", starts_at:, ends_at: starts_at + 1.hour)
      token = connection.sync_token

      connection.remove_busy_block!("1")
      connection.upsert_busy_block!("3", starts_at:, ends_at: starts_at + 1.hour)
      changes = connection.changes_since(token)

      expect(changes.updated.map(&:provider_object_id)).to eq(["3"])
      expect(changes.deleted.map(&:provider_object_id)).to eq(["1"])
      expect(connection.changes_since(changes.token)).to have_attributes(updated: [], deleted: [])
    end

    it "does not bump the sequence when nothing changed" do
      connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)

      expect { connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour) }
        .not_to change(connection, :sync_token)
    end

    it "never rejects a token: unknown, foreign-generation or pruned tokens get the full state" do
      connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)
      connection.upsert_busy_block!("2", starts_at:, ends_at: starts_at + 1.hour)
      connection.remove_busy_block!("2")

      ["garbage", "", "#{SyncCollection::TOKEN_PREFIX}99-1"].each do |token|
        changes = connection.changes_since(token)
        expect(changes.updated.map(&:provider_object_id)).to eq(["1"])
        expect(changes.deleted.map(&:provider_object_id)).to eq(["2"])
      end
    end
  end

  describe "#replace_busy_blocks!" do
    it "upserts the given blocks and removes the others" do
      connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)
      connection.upsert_busy_block!("2", starts_at:, ends_at: starts_at + 1.hour)

      connection.replace_busy_blocks!("2" => { starts_at:, ends_at: starts_at + 2.hours },
                                      "3" => { starts_at:, ends_at: starts_at + 1.hour })

      expect(connection.busy_blocks.live.pluck(:provider_object_id)).to contain_exactly("2", "3")
      expect(connection.busy_blocks.deleted.pluck(:provider_object_id)).to eq(["1"])
    end
  end

  describe "#prune_tombstones!" do
    it "forgets old tombstones and makes older tokens fall back to the full state" do
      connection.upsert_busy_block!("1", starts_at:, ends_at: starts_at + 1.hour)
      old_token = connection.sync_token
      connection.remove_busy_block!("1")
      connection.upsert_busy_block!("2", starts_at:, ends_at: starts_at + 1.hour)

      travel_to(100.days.from_now) { connection.prune_tombstones! }

      expect(connection.busy_blocks.deleted).to be_empty
      expect(connection.changes_since(old_token).updated.map(&:provider_object_id)).to eq(["2"])
    end
  end
end
