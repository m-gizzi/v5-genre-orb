# frozen_string_literal: true

module SpotifyApiHelpers
  # Builds a Spotify track object as returned by the API
  def build_spotify_track(id:, name:, **overrides)
    {
      'id' => id,
      'name' => name,
      'duration_ms' => 180_000,
      'disc_number' => 1,
      'track_number' => 1,
      'explicit' => false,
      'is_local' => false,
      'popularity' => 75,
      'preview_url' => "https://p.scdn.co/mp3-preview/#{id}",
      'external_ids' => { 'isrc' => "ISRC#{id.gsub(/\D/, '').rjust(8, '0')}" },
      'artists' => [build_spotify_artist(id: "artist_#{id}", name: "Artist #{id}")],
      'album' => {
        'name' => 'Test Album',
        'images' => [
          { 'url' => "https://i.scdn.co/image/#{id}_640", 'height' => 640, 'width' => 640 },
          { 'url' => "https://i.scdn.co/image/#{id}_300", 'height' => 300, 'width' => 300 },
          { 'url' => "https://i.scdn.co/image/#{id}_64", 'height' => 64, 'width' => 64 }
        ],
        'release_date' => '2024-01-01'
      },
      'external_urls' => { 'spotify' => "https://open.spotify.com/track/#{id}" },
      'uri' => "spotify:track:#{id}",
      'href' => "https://api.spotify.com/v1/tracks/#{id}"
    }.merge(overrides.stringify_keys)
  end

  # Builds a Spotify artist object
  def build_spotify_artist(id:, name:, **overrides)
    {
      'id' => id,
      'name' => name,
      'type' => 'artist',
      'uri' => "spotify:artist:#{id}",
      'href' => "https://api.spotify.com/v1/artists/#{id}",
      'external_urls' => { 'spotify' => "https://open.spotify.com/artist/#{id}" }
    }.merge(overrides.stringify_keys)
  end

  # Builds a track item as it appears in playlist.tracks responses
  def build_spotify_track_item(track_id:, track_name:, added_at: nil, added_by_id: 'user123', artists: nil, **track_overrides)
    track_data = build_spotify_track(id: track_id, name: track_name, **track_overrides)

    # Override artists if provided
    track_data['artists'] = artists if artists

    {
      'track' => track_data,
      'added_at' => (added_at || Time.current).iso8601,
      'added_by' => { 'id' => added_by_id }
    }
  end

  # Builds a full playlist tracks API response with pagination
  def build_spotify_tracks_response(track_items:, total: nil, limit: 100, offset: 0, next_url: nil, prev_url: nil)
    {
      items: track_items,
      pagination: {
        total: total || track_items.length,
        limit: limit,
        offset: offset,
        next: next_url,
        previous: prev_url
      }
    }
  end

  # Generates multiple track items for testing batch operations
  def generate_track_items(count:, starting_index: 0, artists_per_track: 1)
    Array.new(count) do |i|
      index = starting_index + i
      artists = Array.new(artists_per_track) do |j|
        build_spotify_artist(
          id: "artist#{index}_#{j}",
          name: "Artist #{index}_#{j}"
        )
      end

      build_spotify_track_item(
        track_id: "track#{index}",
        track_name: "Track #{index}",
        artists: artists
      )
    end
  end

  # Builds a Spotify playlist object
  def build_spotify_playlist(id:, name:, snapshot_id: nil, **overrides)
    {
      'id' => id,
      'name' => name,
      'description' => "Description for #{name}",
      'public' => true,
      'collaborative' => false,
      'owner' => { 'id' => 'user123', 'display_name' => 'Test User', 'uri' => 'spotify:user:user123' },
      'snapshot_id' => snapshot_id || SecureRandom.hex(16),
      'tracks' => { 'total' => 0 },
      'images' => [],
      'external_urls' => { 'spotify' => "https://open.spotify.com/playlist/#{id}" },
      'uri' => "spotify:playlist:#{id}",
      'href' => "https://api.spotify.com/v1/playlists/#{id}"
    }.merge(overrides.stringify_keys)
  end

  # Builds a full user playlists API response with pagination
  def build_spotify_playlists_response(playlist_items:, total: nil, limit: 50, offset: 0, next_url: nil, prev_url: nil)
    {
      items: playlist_items,
      pagination: {
        total: total || playlist_items.length,
        limit: limit,
        offset: offset,
        next: next_url,
        previous: prev_url
      }
    }
  end

  # Generates multiple playlists for testing batch operations
  def generate_playlists(count:, starting_index: 0)
    Array.new(count) do |i|
      index = starting_index + i
      build_spotify_playlist(
        id: "playlist#{index}",
        name: "Playlist #{index}"
      )
    end
  end
end

RSpec.configure do |config|
  config.include SpotifyApiHelpers
end
