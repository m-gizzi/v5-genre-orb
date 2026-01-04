# frozen_string_literal: true

module PlaylistTrackSync
  class FetchTrackBatchService < ::FetchBatchService
    include SyncItemConfiguration
  end
end
