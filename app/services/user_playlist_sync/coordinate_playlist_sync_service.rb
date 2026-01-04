# frozen_string_literal: true

module UserPlaylistSync
  class CoordinatePlaylistSyncService < ::CoordinateSyncService
    include SyncItemConfiguration

    BATCH_SIZE = 50

    private

    def batch_job_class
      UserPlaylistSync::FetchPlaylistBatchJob
    end
  end
end
