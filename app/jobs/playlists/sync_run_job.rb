# frozen_string_literal: true

module Playlists
  class SyncRunJob < ApplicationJob
    include SpotifyJobErrorHandling

    discard_on Spotify::Errors::AuthenticationError do |job, error|
      job.handle_authentication_failure(error)
    end

    private

    attr_reader :sync_run, :user

    def initialize_sync_run(sync_run_id)
      @sync_run = PlaylistSyncRun.find(sync_run_id)
      @user = @sync_run.user
    end

    def spotify_client
      @spotify_client ||= Spotify::PlaylistClient.for_user(user)
    end

    def handle_authentication_failure(error)
      sync_run&.update!(status: :failed, error_message: error.message)
    end
  end
end
