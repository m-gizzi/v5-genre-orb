# frozen_string_literal: true

module Tracks
  class ProcessPlaylistJob < SyncRunJob
    def call
      ProcessPlaylistService.call(sync_run: sync_run, force: force)
    end
  end
end
