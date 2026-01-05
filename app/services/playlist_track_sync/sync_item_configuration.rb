# frozen_string_literal: true

module PlaylistTrackSync
  module SyncItemConfiguration
    private

    def sync_item_class
      TrackSyncItem
    end

    def sync_item_foreign_key
      :track_sync_run_id
    end

    def item_foreign_key
      :track_id
    end

    def facade_method_name
      :playlist_track_batch
    end

    def facade_arguments(limit:, offset:)
      {
        user: sync_run.playlist.user,
        playlist: sync_run.playlist,
        limit: limit,
        offset: offset
      }
    end
  end
end
