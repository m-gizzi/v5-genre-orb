# frozen_string_literal: true

module Playlists
  class CoordinatorJob < SyncRunJob
    queue_as :default

    def call
      CoordinatePlaylistSyncService.call(sync_run: sync_run)
    end
  end
end
