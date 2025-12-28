# frozen_string_literal: true

module Spotify
  class TrackClient < BaseClient
    def fetch_playlist_with_tracks(playlist_id, limit: 100, offset: 0)
      handle_spotify_errors('spotify:playlists:tracks') do
        rspotify_playlist = get_rspotify_playlist(playlist_id)
        raw_response = rspotify_playlist.tracks(limit: limit, offset: offset)
        parsed_response = parse_json_response(raw_response)

        {
          snapshot_id: rspotify_playlist.snapshot_id,
          tracks: adapt_playlist_track_items(parsed_response['items']),
          pagination: extract_pagination_metadata(parsed_response)
        }
      end
    end

    private

    def get_rspotify_playlist(playlist_id)
      RSpotify::Playlist.find(rspotify_user.id, playlist_id, rspotify_user)
    end

    def adapt_playlist_track_items(items)
      return [] if items.nil?

      items.map { |item| ResponseAdapters::PlaylistTrackItemAdapter.adapt(item) }
    end
  end
end
