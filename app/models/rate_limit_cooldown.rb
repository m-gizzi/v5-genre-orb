# frozen_string_literal: true

class RateLimitCooldown < ApplicationRecord
  validates :endpoint, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :retry_after_seconds, presence: true, numericality: { greater_than: 0 }

  scope :in_progress, -> { where(expires_at: Time.current..) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  class << self
    def in_progress_for?(endpoint)
      in_progress.exists?(endpoint: endpoint)
    end

    def find_in_progress(endpoint)
      in_progress.find_by(endpoint: endpoint)
    end

    def set_cooldown!(endpoint, retry_after_seconds)
      expires_at = Time.current + retry_after_seconds.seconds

      transaction do
        cooldown = lock.find_or_create_by!(endpoint: endpoint) do |c|
          c.expires_at = expires_at
          c.retry_after_seconds = retry_after_seconds
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

    def cleanup_expired!
      expired.delete_all
    end
  end

  def in_progress?
    expires_at > Time.current
  end

  def seconds_remaining
    [(expires_at - Time.current).ceil, 0].max
  end
end
