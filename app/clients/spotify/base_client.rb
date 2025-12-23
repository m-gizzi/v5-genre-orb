# frozen_string_literal: true

module Spotify
  class BaseClient
    attr_reader :rspotify_user, :user

    def self.for_user(user)
      new(user)
    end

    def initialize(user)
      @user = user
      @rspotify_user = build_rspotify_user
    end

    private

    def build_rspotify_user
      RSpotify::User.new(
        'credentials' => credentials_hash,
        'id' => user.spotify_id
      )
    end

    def credentials_hash
      {
        'token' => user.access_token,
        'refresh_token' => user.refresh_token,
        'access_refresh_callback' => token_refresh_callback
      }
    end

    def token_refresh_callback
      proc do |new_access_token, token_lifetime|
        user.update_spotify_credentials(new_access_token, token_lifetime)
      rescue StandardError => e
        raise Errors::AuthenticationError, "Failed to persist refreshed token: #{e.message}"
      end
    end

    def with_error_handling
      yield
    rescue RestClient::Unauthorized
      raise Errors::AuthenticationError, 'Spotify authentication failed. Please re-authorize.'
    rescue RestClient::TooManyRequests => e
      retry_after = e.response.headers[:retry_after]&.to_i
      raise Errors::RateLimitError.new('Spotify rate limit exceeded', retry_after: retry_after)
    rescue RestClient::ExceptionWithResponse => e
      raise Errors::ApiError, "Spotify API error: #{e.message}"
    end
  end
end
