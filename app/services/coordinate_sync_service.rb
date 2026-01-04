# frozen_string_literal: true

class CoordinateSyncService < ApplicationService
  include SyncRunStatsUpdater
  include SyncItemManager

  def initialize(sync_run:)
    @sync_run = sync_run
  end

  def call
    sync_run.start_fetching_metadata!

    first_batch_result = fetch_and_persist(limit: batch_size, offset: 0)
    calculate_and_set_totals(first_batch_result)

    sync_run.start_processing_batches!

    update_sync_run_stats(sync_run, first_batch_result[:counts])
    create_sync_items(first_batch_result[:item_ids])
    sync_run.increment_batch_completion!
    enqueue_remaining_batches
  end

  private

  attr_reader :sync_run

  def batch_job_class
    raise NotImplementedError, "#{self.class} must implement #batch_job_class"
  end

  def calculate_and_set_totals(result)
    total_count = result[:pagination][:total]
    batches_needed = calculate_batches_needed(total_count)

    sync_run.update!(batches_total: batches_needed)
  end

  def batch_size
    self.class::BATCH_SIZE
  end

  def calculate_batches_needed(total_count)
    return 1 if total_count.zero?

    (total_count.to_f / batch_size).ceil
  end

  def enqueue_remaining_batches
    (1...sync_run.batches_total).each do |batch_index|
      offset = batch_index * batch_size
      batch_job_class.perform_later(sync_run.id, offset, batch_size)
    end
  end
end
