# frozen_string_literal: true

module Spotify
  class PlaylistClient < BaseClient
    def fetch_user_playlists(limit: 50, offset: 0)
      handle_spotify_errors('spotify:playlists') do
        playlists = rspotify_user.playlists(limit: limit, offset: offset)
        playlists.map { |playlist| ResponseAdapters::PlaylistAdapter.adapt(playlist) }
      end
    end

    def fetch_all_user_playlists
      all_playlists = []
      offset = 0
      limit = 50

      loop do
        batch = fetch_user_playlists(limit: limit, offset: offset)
        break if batch.empty?

        all_playlists.concat(batch)
        offset += limit
      end

      all_playlists
    end

    def create_playlist(name:, description: nil, public: true)
      handle_spotify_errors('spotify:playlists') do
        playlist = rspotify_user.create_playlist!(name, public: public, description: description)
        ResponseAdapters::PlaylistAdapter.adapt(playlist)
      end
    end
  end
end
