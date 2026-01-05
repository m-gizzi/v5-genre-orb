# frozen_string_literal: true

module Spotify
  class BaseRepository
    attr_reader :counts

    def initialize
      @counts = {}
    end

    private

    def increment_count(count_name, amount = 1)
      counts[count_name] ||= 0
      counts[count_name] += amount
    end

    def counts_hash
      counts.dup
    end
  end
end
