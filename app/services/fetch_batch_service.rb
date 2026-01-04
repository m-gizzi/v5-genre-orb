# frozen_string_literal: true

class FetchBatchService < ApplicationService
  include SyncRunStatsUpdater
  include SyncItemManager

  def initialize(sync_run:, offset:, limit:)
    @sync_run = sync_run
    @offset = offset
    @limit = limit
  end

  def call
    result = fetch_and_persist(limit: limit, offset: offset)

    update_sync_run_stats(sync_run, result[:counts])
    create_sync_items(result[:item_ids])
    sync_run.increment_batch_completion!
  end

  private

  attr_reader :sync_run, :offset, :limit
end
