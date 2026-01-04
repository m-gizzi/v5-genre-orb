# frozen_string_literal: true

module Tracks
  class FetchTrackBatchService < ApplicationService
    def initialize(sync_run:, offset:, limit:)
      @sync_run = sync_run
      @playlist = sync_run.playlist
      @offset = offset
      @limit = limit
    end

    def call
      result = FetchAndPersistService.new.fetch_and_persist_batch(
        user: playlist.user,
        playlist: playlist,
        limit: limit,
        offset: offset
      )

      update_sync_run_stats(result[:counts])
      create_track_sync_items(result[:track_ids])
      sync_run.increment_batch_completion!
    end

    private

    attr_reader :sync_run, :playlist, :offset, :limit

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
  end
end
