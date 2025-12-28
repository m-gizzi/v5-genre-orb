# frozen_string_literal: true

module Spotify
  module ResponseAdapters
    class ArtistAdapter
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
          external_urls: data['external_urls'],
          href: data['href'],
          uri: data['uri'],
          type: data['type']
        }
      end
    end
  end
end
