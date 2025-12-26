# frozen_string_literal: true

module Playlists
  class SpotifyBatchProcessor
    attr_reader :sync_run, :user

    def initialize(sync_run:)
      @sync_run = sync_run
      @user = sync_run.user
    end

    def process_batch(playlists)
      playlists.each do |playlist_data|
        upsert_playlist(playlist_data)
        increment_progress_counter(:playlists_processed)
      end
    end

    def mark_batch_complete!
      sync_run.increment_batch_completion!
    end

    private

    def upsert_playlist(playlist_data)
      playlist = user.playlists.find_or_initialize_by(spotify_id: playlist_data[:spotify_id])
      playlist.assign_attributes(
        name: playlist_data[:name],
        description: playlist_data[:description],
        raw_data: playlist_data,
        archived_at: nil
      )
      playlist.save!

      PlaylistSyncItem.find_or_create_by!(
        playlist_sync_run_id: sync_run.id,
        playlist_id: playlist.id
      )
    end

    def increment_progress_counter(counter_name)
      sync_run.with_lock do
        sync_run.increment!(counter_name)
      end
    end
  end
end
