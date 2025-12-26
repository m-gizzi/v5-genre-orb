# frozen_string_literal: true

module Playlists
  class ArchiveMissingJob < ApplicationJob
    include SpotifyJobErrorHandling

    queue_as :default

    def perform(sync_run_id)
      @sync_run = PlaylistSyncRun.find(sync_run_id)
      @user = @sync_run.user

      archive_missing_playlists
      mark_sync_completed
    end

    private

    attr_reader :sync_run, :user

    def archive_missing_playlists
      synced_playlist_ids = sync_run.playlist_sync_items.pluck(:playlist_id)

      user.playlists
        .where(archived_at: nil)
        .where.not(id: synced_playlist_ids)
        .update_all(archived_at: Time.current)
    end

    def mark_sync_completed
      sync_run.update!(
        status: :completed,
        completed_at: Time.current
      )
    end
  end
end
