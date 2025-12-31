# frozen_string_literal: true

module Spotify
  class PlaylistRepository < BaseRepository
    attr_reader :user

    def initialize(user:)
      super()
      @user = user
    end

    def process_batch(raw_items)
      playlist_ids = []

      raw_items.each do |raw_item|
        playlist = upsert_playlist(raw_item)
        playlist_ids << playlist.id
        increment_count(:playlists_processed)
      end

      {
        counts: counts_hash,
        playlist_ids: playlist_ids
      }
    end

    private

    def upsert_playlist(raw_data)
      playlist = user.playlists.find_or_initialize_by(spotify_id: raw_data['id'])
      playlist.assign_attributes(
        name: raw_data['name'],
        description: raw_data['description'],
        raw_data: raw_data
      )

      playlist.archived_at = nil
      playlist.save!
      playlist
    end
  end
end
