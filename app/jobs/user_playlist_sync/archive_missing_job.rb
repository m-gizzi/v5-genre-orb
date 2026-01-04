# frozen_string_literal: true

module UserPlaylistSync
  class ArchiveMissingJob < Base
    def call
      archive_missing_playlists
      sync_run.complete! if sync_run.may_complete?
    end

    private

    def archive_missing_playlists
      synced_playlist_ids = sync_run.playlist_sync_items.pluck(:playlist_id)

      sync_run.user.playlists
              .active
              .where.not(id: synced_playlist_ids)
              .update_all(archived_at: Time.current)
    end
  end
end
