# frozen_string_literal: true

module Playlists
  class FetchBatchJob < ApplicationJob
    include SpotifyJobErrorHandling

    queue_as :default

    def perform(sync_run_id, offset, limit = 50)
      @sync_run = PlaylistSyncRun.find(sync_run_id)
      @user = @sync_run.user
      @offset = offset
      @limit = limit

      fetch_and_process_batch
    end

    private

    attr_reader :sync_run, :user, :offset, :limit

    def fetch_and_process_batch
      playlists = fetch_playlists_from_spotify
      process_playlists(playlists)
      complete_batch
    end

    def fetch_playlists_from_spotify
      client = Spotify::PlaylistClient.for_user(user)
      client.fetch_user_playlists(limit: limit, offset: offset)
    end

    def process_playlists(playlists)
      playlists.each do |playlist_data|
        upsert_playlist(playlist_data)
        increment_progress_counter(:playlists_processed)
      end
    end

    def upsert_playlist(playlist_data)
      playlist = user.playlists.find_or_initialize_by(spotify_id: playlist_data[:spotify_id])
      playlist.assign_attributes(
        name: playlist_data[:name],
        description: playlist_data[:description],
        raw_data: playlist_data,
        archived_at: nil
      )
      playlist.save!
    end

    def increment_progress_counter(counter_name)
      sync_run.with_lock do
        sync_run.increment!(counter_name)
      end
    end

    def complete_batch
      sync_run.increment_batch_completion!
    end
  end
end
