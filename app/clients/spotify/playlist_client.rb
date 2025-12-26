# frozen_string_literal: true

module Spotify
  class PlaylistClient < BaseClient
    def fetch_user_playlists(limit: 50, offset: 0)
      handle_spotify_errors('spotify:users:playlists') do
        playlists = rspotify_user.playlists(limit: limit, offset: offset)
        playlists.map { |playlist| ResponseAdapters::PlaylistAdapter.adapt(playlist) }
      end
    end

    def create_playlist(name:, description: nil, public: true)
      handle_spotify_errors('spotify:users:create_playlist') do
        playlist = rspotify_user.create_playlist!(name, public: public, description: description)
        ResponseAdapters::PlaylistAdapter.adapt(playlist)
      end
    end
  end
end
