# frozen_string_literal: true

module Tracks
  class FetchTrackBatchJob < SyncRunJob
    def call
      FetchTrackBatchService.call(
        sync_run: sync_run,
        offset: offset,
        limit: limit
      )
    end
  end
end
