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

    def handle_spotify_errors(endpoint)
      check_rate_limit_cooldown!(endpoint)
      yield
    rescue RestClient::Unauthorized
      handle_unauthorized_error
    rescue RestClient::TooManyRequests => e
      handle_rate_limit_error(e, endpoint)
    rescue RestClient::ExceptionWithResponse => e
      handle_api_error(e)
    end

    def check_rate_limit_cooldown!(endpoint)
      cooldown = RateLimitCooldown.find_in_progress(endpoint)
      return unless cooldown

      raise Errors::RateLimitCooldownActive.new(
        "Endpoint #{endpoint} is rate limited until #{cooldown.expires_at}",
        retry_after: cooldown.seconds_remaining
      )
    end

    def handle_unauthorized_error
      raise Errors::AuthenticationError, 'Spotify authentication failed. Please re-authorize.'
    end

    def handle_rate_limit_error(error, endpoint)
      retry_after = error.response.headers[:retry_after]&.to_i
      RateLimitCooldown.set_cooldown!(endpoint, retry_after)

      raise Errors::RateLimitError.new(
        "Rate limit exceeded, retry after #{retry_after}s",
        retry_after: retry_after
      )
    end

    def handle_api_error(error)
      raise Errors::ApiError, "Spotify API error: #{error.message}"
    end
  end
end
