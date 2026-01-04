# frozen_string_literal: true

module Tracks
  class ProcessPlaylistJob < SyncRunJob
    def call
      CoordinateTrackSyncService.call(sync_run: sync_run)
    end
  end
end
