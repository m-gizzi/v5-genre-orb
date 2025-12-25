# frozen_string_literal: true

module Spotify
  module Errors
    class BaseError < StandardError; end
    class AuthenticationError < BaseError; end
    class ApiError < BaseError; end

    class RateLimitError < BaseError
      attr_reader :retry_after

      def initialize(message = 'Rate limit exceeded', retry_after: nil)
        super(message)
        @retry_after = retry_after
      end
    end

    class RateLimitCooldownActive < RateLimitError; end
  end
end
