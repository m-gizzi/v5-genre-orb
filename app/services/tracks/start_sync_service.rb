# frozen_string_literal: true

module Tracks
  class StartSyncService < ApplicationService
    def initialize(playlist, force: false)
      @playlist = playlist
      @force = force
    end

    def call
      existing = find_in_progress_sync
      return existing if existing

      create_new_sync
    rescue ActiveRecord::RecordNotUnique
      find_in_progress_sync
    end

    private

    attr_reader :playlist, :force

    def find_in_progress_sync
      TrackSyncRun.in_progress_for_playlist(playlist)
    end

    def create_new_sync
      sync_run = TrackSyncRun.create!(playlist: playlist, status: :pending)
      Tracks::ProcessPlaylistJob.perform_later(sync_run.id, force)
      sync_run
    end
  end
end
