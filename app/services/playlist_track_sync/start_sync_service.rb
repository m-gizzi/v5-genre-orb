# frozen_string_literal: true

module PlaylistTrackSync
  class StartSyncService < ApplicationService
    def initialize(playlist, force: false)
      @playlist = playlist
      @force = force
    end

    def call
      existing = find_in_progress_sync
      return existing if existing

      return nil unless should_sync?

      create_new_sync
    rescue ActiveRecord::RecordNotUnique
      find_in_progress_sync
    end

    private

    attr_reader :playlist, :force

    def should_sync?
      return true if force

      fetch_and_check_snapshot
    end

    def fetch_and_check_snapshot
      FetchAndPersistFacade.single_playlist(
        user: playlist.user,
        spotify_id: playlist.spotify_id
      )

      playlist.reload

      playlist.last_track_sync_snapshot_id.nil? ||
        playlist.snapshot_id != playlist.last_track_sync_snapshot_id
    rescue Spotify::Errors::AuthenticationError, Spotify::Errors::ApiError
      true
    end

    def find_in_progress_sync
      TrackSyncRun.in_progress_for_playlist(playlist)
    end

    def create_new_sync
      sync_run = TrackSyncRun.create!(playlist: playlist, status: :pending)
      PlaylistTrackSync::CoordinatorJob.perform_later(sync_run.id)
      sync_run
    end
  end
end
