# frozen_string_literal: true

module Playlists
  class FetchBatchJob < SyncRunJob
    queue_as :default

    def call(offset, limit = 50)
      FetchPlaylistBatchService.call(
        sync_run: sync_run,
        offset: offset,
        limit: limit
      )
    end
  end
end
