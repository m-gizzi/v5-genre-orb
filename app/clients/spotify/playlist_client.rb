# frozen_string_literal: true

module Spotify
  class PlaylistClient < BaseClient
    def fetch_user_playlists(limit: 50, offset: 0)
      handle_spotify_errors('spotify:users:playlists') do
        raw_response = rspotify_user.playlists(limit: limit, offset: offset)
        parsed_response = parse_json_response(raw_response)

        {
          items: parsed_response['items'] || [],
          pagination: extract_pagination_metadata(parsed_response)
        }
      end
    end

    def create_playlist(name:, description: nil, public: true)
      handle_spotify_errors('spotify:users:create_playlist') do
        raw_response = rspotify_user.create_playlist!(name, public: public, description: description)
        parse_json_response(raw_response)
      end
    end
  end
end
