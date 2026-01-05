# frozen_string_literal: true

module UserPlaylistSync
  class Base < ::SyncRunJob
    private

    def sync_run_class
      PlaylistSyncRun
    end
  end
end
