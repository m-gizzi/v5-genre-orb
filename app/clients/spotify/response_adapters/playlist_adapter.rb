# frozen_string_literal: true

module Spotify
  module ResponseAdapters
    class PlaylistAdapter
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
          description: data['description'],
          public: data['public'],
          collaborative: data['collaborative'],
          owner: owner_data,
          snapshot_id: data['snapshot_id'],
          tracks_total: data.dig('tracks', 'total'),
          images: images_data,
          external_urls: data['external_urls'],
          uri: data['uri'],
          href: data['href']
        }
      end

      private

      def owner_data
        return nil unless data['owner']

        {
          id: data['owner']['id'],
          display_name: data['owner']['display_name'],
          uri: data['owner']['uri']
        }
      end

      def images_data
        return [] unless data['images']

        data['images'].map do |image|
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
