# frozen_string_literal: true

class RateLimitCooldown < ApplicationRecord
  DEFAULT_RETRY_AFTER = 60

  validates :endpoint, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :retry_after_seconds, presence: true, numericality: { greater_than: 0 }

  scope :in_progress, -> { where(expires_at: Time.current..) }

  class << self
    def find_in_progress(endpoint)
      in_progress.find_by(endpoint: endpoint)
    end

    def set_cooldown!(endpoint, retry_after_seconds)
      retry_after_seconds ||= DEFAULT_RETRY_AFTER
      expires_at = Time.current + retry_after_seconds.seconds

      transaction do
        cooldown = lock.find_or_create_by!(endpoint: endpoint) do |new_cooldown|
          new_cooldown.expires_at = expires_at
          new_cooldown.retry_after_seconds = retry_after_seconds
        end

        if expires_at > cooldown.expires_at
          cooldown.update!(
            expires_at: expires_at,
            retry_after_seconds: retry_after_seconds
          )
        end

        cooldown
      end
    end
  end

  def seconds_remaining
    [(expires_at - Time.current).ceil, 0].max
  end
end
