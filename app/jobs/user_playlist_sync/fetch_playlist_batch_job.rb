# frozen_string_literal: true

module UserPlaylistSync
  class FetchPlaylistBatchJob < Base
    def call(offset, limit = 50)
      FetchPlaylistBatchService.call(
        sync_run: sync_run,
        offset: offset,
        limit: limit
      )
    end
  end
end
