# frozen_string_literal: true

module PlaylistTrackSync
  class CoordinateTrackSyncService < ::CoordinateSyncService
    include SyncItemConfiguration

    BATCH_SIZE = 100

    private

    def batch_job_class
      PlaylistTrackSync::FetchTrackBatchJob
    end
  end
end
