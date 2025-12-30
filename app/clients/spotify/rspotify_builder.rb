# frozen_string_literal: true

module Spotify
  class RSpotifyBuilder
    class << self
      def build_user(user)
        RSpotify::User.new(
          'credentials' => build_user_credentials(user),
          'id' => user.spotify_id
        )
      end

      def build_playlist(playlist)
        RSpotify::Playlist.new(playlist.raw_data.stringify_keys)
      end

      private

      def build_user_credentials(user)
        {
          'token' => user.access_token,
          'refresh_token' => user.refresh_token,
          'access_refresh_callback' => token_refresh_callback(user)
        }
      end

      def token_refresh_callback(user)
        proc do |new_access_token, token_lifetime|
          user.update_spotify_credentials(new_access_token, token_lifetime)
        rescue StandardError => e
          raise Errors::AuthenticationError, "Failed to persist refreshed token: #{e.message}"
        end
      end
    end
  end
end
