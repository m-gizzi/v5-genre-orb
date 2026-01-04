# frozen_string_literal: true

module UserPlaylistSync
  module SyncItemConfiguration
    private

    def sync_item_class
      PlaylistSyncItem
    end

    def sync_item_foreign_key
      :playlist_sync_run_id
    end

    def item_foreign_key
      :playlist_id
    end

    def facade_method_name
      :user_playlist_batch
    end

    def facade_arguments(limit:, offset:)
      {
        user: sync_run.user,
        limit: limit,
        offset: offset
      }
    end
  end
end
