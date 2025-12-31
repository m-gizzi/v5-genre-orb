# frozen_string_literal: true

module Spotify
  class TrackClient < BaseClient
    def fetch_playlist_tracks(playlist, limit: 100, offset: 0)
      handle_spotify_errors('spotify:playlists:tracks') do
        rspotify_playlist = RspotifyBuilder.build_playlist(playlist)
        raw_response = rspotify_playlist.tracks(limit: limit, offset: offset)
        parsed_response = parse_json_response(raw_response)

        {
          items: parsed_response['items'] || [],
          pagination: extract_pagination_metadata(parsed_response)
        }
      end
    end
  end
end
