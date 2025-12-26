# frozen_string_literal: true

module Playlists
  class SyncRunJob < ApplicationJob
    include SpotifyJobErrorHandling

    discard_on Spotify::Errors::AuthenticationError do |job, error|
      job.handle_authentication_failure(error)
    end

    def perform(sync_run_id, *args)
      @sync_run = PlaylistSyncRun.find(sync_run_id)

      call(*args)
    end

    private

    attr_reader :sync_run

    def handle_authentication_failure(error)
      sync_run&.update!(status: :failed, error_message: error.message)
    end
  end
end
