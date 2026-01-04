# frozen_string_literal: true

module Tracks
  class CleanupRemovedJob < SyncRunJob
    queue_as :default

    def call
      cleanup_removed_playlist_tracks
      sync_run.complete! if sync_run.may_complete?
    end

    private

    def cleanup_removed_playlist_tracks
      synced_track_ids = sync_run.track_sync_items.pluck(:track_id)

      sync_run.playlist.playlist_tracks
              .where.not(track_id: synced_track_ids)
              .destroy_all
    end
  end
end
