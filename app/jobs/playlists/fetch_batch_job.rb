# frozen_string_literal: true

module Playlists
  class FetchBatchJob < SyncRunJob
    queue_as :default

    def call(offset, limit = 50)
      @offset = offset
      @limit = limit

      fetch_and_process_batch
    end

    private

    attr_reader :offset, :limit

    def fetch_and_process_batch
      playlists = fetch_playlists_from_spotify
      process_playlists(playlists)
      complete_batch
    end

    def fetch_playlists_from_spotify
      spotify_client.fetch_user_playlists(limit: limit, offset: offset)
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

    def complete_batch
      sync_run.increment_batch_completion!
    end
  end
end
