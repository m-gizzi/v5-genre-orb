# frozen_string_literal: true

module Spotify
  module ResponseAdapters
    class PlaylistAdapter
      def self.adapt(rspotify_playlist)
        new(rspotify_playlist).adapt
      end

      attr_reader :playlist

      def initialize(rspotify_playlist)
        @playlist = rspotify_playlist
      end

      def adapt
        {
          spotify_id: playlist.id,
          name: playlist.name,
          description: playlist.description,
          public: playlist.public,
          collaborative: playlist.collaborative,
          owner: owner_data,
          snapshot_id: playlist.snapshot_id,
          tracks_total: playlist.total,
          images: images_data,
          external_urls: playlist.external_urls,
          uri: playlist.uri,
          href: playlist.href
        }
      end

      private

      def owner_data
        return nil unless playlist.owner

        {
          id: playlist.owner.id,
          display_name: playlist.owner.display_name,
          uri: playlist.owner.uri
        }
      end

      def images_data
        return [] unless playlist.images

        playlist.images.map do |image|
          {
            url: image['url'],
            height: image['height'],
            width: image['width']
          }
        end
      end
    end
  end
end
