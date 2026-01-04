# frozen_string_literal: true

module UserPlaylistSync
  class CoordinatorJob < Base
    def call
      CoordinatePlaylistSyncService.call(sync_run: sync_run)
    end
  end
end
