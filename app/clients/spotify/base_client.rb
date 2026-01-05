# frozen_string_literal: true

module Spotify
  class BaseClient
    attr_reader :rspotify_user, :user

    def self.for_user(user)
      new(user)
    end

    def initialize(user)
      @user = user
      @rspotify_user = RspotifyBuilder.build_user(user)
    end

    private

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

    def parse_json_response(raw_response)
      return raw_response if raw_response.is_a?(Hash) || raw_response.is_a?(Array)

      JSON.parse(raw_response)
    rescue JSON::ParserError => e
      raise Spotify::Errors::ApiError, "Failed to parse Spotify response: #{e.message}"
    end

    def extract_pagination_metadata(response)
      {
        total: response['total'],
        limit: response['limit'],
        offset: response['offset'],
        next: response['next'],
        previous: response['previous']
      }
    end
  end
end
