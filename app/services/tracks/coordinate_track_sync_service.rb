# frozen_string_literal: true

module Tracks
  class CoordinateTrackSyncService < ApplicationService
    BATCH_SIZE = 100

    def initialize(sync_run:)
      @sync_run = sync_run
      @playlist = sync_run.playlist
    end

    def call
      sync_run.start_fetching_metadata!

      first_batch_result = fetch_and_persist_first_batch

      calculate_and_set_totals(first_batch_result)
      sync_run.start_processing_batches!

      update_sync_run_stats(first_batch_result[:counts])
      create_track_sync_items(first_batch_result[:track_ids])
      sync_run.increment_batch_completion!

      enqueue_remaining_batches
    end

    private

    attr_reader :sync_run, :playlist

    def fetch_and_persist_first_batch
      FetchAndPersistService.new.fetch_and_persist_batch(
        user: playlist.user,
        playlist: playlist,
        limit: BATCH_SIZE,
        offset: 0
      )
    end

    def calculate_and_set_totals(result)
      total_tracks = result[:pagination][:total]
      batches_total = (total_tracks.to_f / BATCH_SIZE).ceil

      sync_run.update!(batches_total: batches_total)
    end

    def update_sync_run_stats(stats)
      sync_run.with_lock do
        stats.each do |stat_name, count|
          sync_run.increment!(stat_name, count)
        end
      end
    end

    def create_track_sync_items(track_ids)
      track_ids.each do |track_id|
        TrackSyncItem.find_or_create_by!(
          track_sync_run_id: sync_run.id,
          track_id: track_id
        )
      end
    end

    def enqueue_remaining_batches
      (1...sync_run.batches_total).each do |batch_index|
        offset = batch_index * BATCH_SIZE
        Tracks::FetchTrackBatchJob.perform_later(sync_run.id, offset, BATCH_SIZE)
      end
    end
  end
end
