# frozen_string_literal: true

module Spotify
  module ResponseAdapters
    class PlaylistTrackItemAdapter
      def self.adapt(json_hash)
        new(json_hash).adapt
      end

      attr_reader :data

      def initialize(json_hash)
        @data = json_hash
      end

      def adapt
        {
          added_at: data['added_at'],
          added_by_spotify_id: data.dig('added_by', 'id'),
          is_local: data['is_local'],
          track: TrackAdapter.adapt(data['track'])
        }
      end
    end
  end
end
