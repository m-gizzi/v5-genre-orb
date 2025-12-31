# frozen_string_literal: true

module Tracks
  class FetchTrackBatchService < ApplicationService
    def initialize(sync_run:, offset:, limit:, snapshot_id:)
      @sync_run = sync_run
      @playlist = sync_run.playlist
      @offset = offset
      @limit = limit
      @snapshot_id = snapshot_id
    end

    def call
      result = FetchAndPersistService.new.fetch_and_persist_batch(
        user: playlist.user,
        playlist: playlist,
        limit: limit,
        offset: offset
      )

      update_sync_run_stats(result[:counts])
      sync_run.increment_batch_completion!
      return unless sync_run.completed?

      playlist.mark_tracks_synced!(result[:snapshot_id])
    end

    private

    attr_reader :sync_run, :playlist, :offset, :limit, :snapshot_id

    def update_sync_run_stats(stats)
      sync_run.with_lock do
        stats.each do |stat_name, count|
          sync_run.increment!(stat_name, count)
        end
      end
    end
  end
end
