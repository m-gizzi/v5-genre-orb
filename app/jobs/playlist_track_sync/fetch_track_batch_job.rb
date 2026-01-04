# frozen_string_literal: true

module PlaylistTrackSync
  class FetchTrackBatchJob < Base
    def call(offset, limit)
      FetchTrackBatchService.call(
        sync_run: sync_run,
        offset: offset,
        limit: limit
      )
    end
  end
end
