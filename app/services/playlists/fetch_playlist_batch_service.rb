# frozen_string_literal: true

module Playlists
  class FetchPlaylistBatchService < ApplicationService
    def initialize(sync_run:, offset:, limit:)
      @sync_run = sync_run
      @offset = offset
      @limit = limit
    end

    def call
      result = FetchAndPersistService.new.fetch_and_persist_batch(
        user: sync_run.user,
        limit: limit,
        offset: offset
      )

      update_sync_run_stats(result[:counts])
      create_playlist_sync_items(result[:playlist_ids])
      sync_run.increment_batch_completion!
    end

    private

    attr_reader :sync_run, :offset, :limit

    def update_sync_run_stats(stats)
      stats.with_lock do
        stats_to_update.each do |stat_name, count|
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
  end
end
