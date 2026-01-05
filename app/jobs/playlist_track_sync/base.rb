# frozen_string_literal: true

module PlaylistTrackSync
  class Base < ::SyncRunJob
    private

    def sync_run_class
      TrackSyncRun
    end
  end
end
