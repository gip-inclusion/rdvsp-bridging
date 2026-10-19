# WebDAV sync-collection (RFC 6578) semantics over the busy blocks mirror.
#
# RDV-SP cannot recover from a sync error, so a token is never rejected: an unknown token, a token from another
# generation or one older than the pruned tombstones gets the full state (all live blocks and all tombstones).
module SyncCollection
  extend ActiveSupport::Concern

  TOKEN_PREFIX = "urn:rdvsp-bridges:sync:".freeze
  TOMBSTONE_RETENTION = 90.days

  Changes = Data.define(:updated, :deleted, :token)

  def sync_token
    "#{TOKEN_PREFIX}#{sync_generation}-#{busy_blocks.maximum(:seq) || 0}"
  end

  def changes_since(token)
    seq = seq_from(token)
    scope = seq ? busy_blocks.changed_after(seq) : busy_blocks
    Changes.new(updated: scope.live.order(:seq).to_a, deleted: scope.deleted.order(:seq).to_a, token: sync_token)
  end

  def upsert_busy_block!(provider_object_id, starts_at:, ends_at:)
    block = busy_blocks.find_or_initialize_by(provider_object_id: provider_object_id.to_s)
    return block if block.persisted? && !block.deleted? && block.starts_at == starts_at && block.ends_at == ends_at

    block.update!(starts_at:, ends_at:, deleted_at: nil, seq: BusyBlockChange.next_seq(self))
    block
  end

  def remove_busy_block!(provider_object_id)
    block = busy_blocks.live.find_by(provider_object_id: provider_object_id.to_s)
    block&.update!(deleted_at: Time.current, seq: BusyBlockChange.next_seq(self))
  end

  # Full replacement: blocks absent from `blocks_by_id` ({ provider_object_id => { starts_at:, ends_at: } }) are removed
  def replace_busy_blocks!(blocks_by_id)
    transaction do
      blocks_by_id.each { |id, times| upsert_busy_block!(id, **times) }
      busy_blocks.live.where.not(provider_object_id: blocks_by_id.keys.map(&:to_s)).find_each do |block|
        remove_busy_block!(block.provider_object_id)
      end
      update!(rebuilt_at: Time.current)
    end
  end

  def prune_tombstones!
    expired = busy_blocks.deleted.where(deleted_at: ...TOMBSTONE_RETENTION.ago)
    max_seq = expired.maximum(:seq)
    return if max_seq.nil?

    transaction do
      expired.delete_all
      update!(pruned_through_seq: [pruned_through_seq, max_seq].max)
    end
  end

  private

  def seq_from(token)
    match = token.to_s.delete_prefix(TOKEN_PREFIX).match(/\A(\d+)-(\d+)\z/)
    return if match.nil?

    generation, seq = match.captures.map(&:to_i)
    seq if generation == sync_generation && seq >= pruned_through_seq
  end
end
