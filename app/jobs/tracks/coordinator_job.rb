# frozen_string_literal: true

module Tracks
  class CoordinatorJob < SyncRunJob
    def call
      CoordinateTrackSyncService.call(sync_run: sync_run)
    end
  end
end
