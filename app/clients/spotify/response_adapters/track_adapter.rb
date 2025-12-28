# frozen_string_literal: true

module Spotify
  module ResponseAdapters
    class TrackAdapter
      def self.adapt(json_hash)
        new(json_hash).adapt
      end

      attr_reader :data

      def initialize(json_hash)
        @data = json_hash
      end

      def adapt
        {
          spotify_id: data['id'],
          name: data['name'],
          duration_ms: data['duration_ms'],
          disc_number: data['disc_number'],
          track_number: data['track_number'],
          explicit: data['explicit'],
          is_local: data['is_local'],
          popularity: data['popularity'],
          preview_url: data['preview_url'],
          isrc: data.dig('external_ids', 'isrc'),
          album: album_data,
          artists: artists_data,
          external_urls: data['external_urls'],
          uri: data['uri'],
          href: data['href']
        }
      end

      private

      def album_data
        album = data['album']
        return nil unless album

        {
          id: album['id'],
          name: album['name'],
          release_date: album['release_date'],
          images: album['images'],
          uri: album['uri']
        }
      end

      def artists_data
        return [] unless data['artists']

        data['artists'].map { |a| ArtistAdapter.adapt(a) }
      end
    end
  end
end
