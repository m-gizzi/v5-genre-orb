# frozen_string_literal: true

module UserPlaylistSync
  class FetchPlaylistBatchService < ::FetchBatchService
    include SyncItemConfiguration
  end
end
