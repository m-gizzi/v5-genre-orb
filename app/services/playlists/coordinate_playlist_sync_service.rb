# frozen_string_literal: true

module Playlists
  class CoordinatePlaylistSyncService < ApplicationService
    BATCH_SIZE = 50

    def initialize(sync_run:)
      @sync_run = sync_run
    end

    def call
      sync_run.start_fetching_metadata!

      first_batch_result = fetch_and_persist_first_batch
      calculate_and_set_totals(first_batch_result)

      sync_run.start_processing_batches!

      update_sync_run_stats(first_batch_result[:counts])
      create_playlist_sync_items(first_batch_result[:playlist_ids])
      sync_run.increment_batch_completion!
      enqueue_remaining_batch_jobs
    end

    private

    attr_reader :sync_run

    def fetch_and_persist_first_batch
      FetchAndPersistFacade.user_playlist_batch(
        user: sync_run.user,
        limit: BATCH_SIZE,
        offset: 0
      )
    end

    def calculate_and_set_totals(result)
      total_count = result[:pagination][:total]
      batches_needed = calculate_batches_needed(total_count)

      sync_run.update!(
        total_playlists_expected: total_count,
        batches_total: batches_needed
      )
    end

    def calculate_batches_needed(total_count)
      return 1 if total_count.zero?

      (total_count.to_f / BATCH_SIZE).ceil
    end

    def update_sync_run_stats(stats)
      sync_run.with_lock do
        stats.each do |stat_name, count|
          sync_run.increment!(stat_name, count)
        end
      end
    end

    def create_playlist_sync_items(playlist_ids)
      playlist_ids.each do |playlist_id|
        PlaylistSyncItem.find_or_create_by!(
          playlist_sync_run_id: sync_run.id,
          playlist_id: playlist_id
        )
      end
    end

    def enqueue_remaining_batch_jobs
      batches_total = sync_run.batches_total

      (1...batches_total).each do |batch_index|
        offset = batch_index * BATCH_SIZE
        Playlists::FetchBatchJob.perform_later(sync_run.id, offset, BATCH_SIZE)
      end
    end
  end
end
