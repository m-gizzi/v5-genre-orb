# frozen_string_literal: true

module SpotifyJobErrorHandling
  extend ActiveSupport::Concern

  included do
    retry_on Spotify::Errors::RateLimitCooldownActive, attempts: 10 do |job, error|
      job.retry_job(wait: error.retry_after.seconds)
    end

    retry_on Spotify::Errors::RateLimitError, attempts: 10 do |job, error|
      wait_time = error.retry_after
      job.retry_job(wait: wait_time.seconds)
    end

    retry_on Spotify::Errors::ApiError, wait: 5.seconds, attempts: 3
    retry_on ActiveRecord::Deadlocked, wait: 1.second, attempts: 3
    retry_on ActiveRecord::RecordNotUnique, wait: 1.second, attempts: 3

    discard_on Spotify::Errors::AuthenticationError do |job, error|
      handle_authentication_failure(job, error)
    end

    discard_on ActiveRecord::RecordNotFound
  end

  class_methods do
    def handle_authentication_failure(job, error)
      sync_run_id = job.arguments.first
      sync_run = PlaylistSyncRun.find_by(id: sync_run_id)
      sync_run&.update!(status: :failed, error_message: error.message)
    end
  end
end
