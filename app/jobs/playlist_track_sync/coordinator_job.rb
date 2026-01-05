# frozen_string_literal: true

module PlaylistTrackSync
  class CoordinatorJob < Base
    def call
      CoordinateTrackSyncService.call(sync_run: sync_run)
    end
  end
end
